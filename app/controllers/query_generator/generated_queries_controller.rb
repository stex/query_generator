module QueryGenerator
  class GeneratedQueriesController < ApplicationController
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    #Set the layout based on the current QueryGenerator::Configuration
    layout QueryGenerator::Configuration.get(:controller)[:layout]

    #Make the query_generator_session available in views
    helper_method :query_generator_session, :conf, :dh, :human_model_name, :wizard_file, :model_dom_id, :handle_dom_id_options, :ccan?

    #Load the requested model from params
    before_filter :load_model_from_params, :only => [:add_association, :preview_model_records,
                                                     :set_main_model, :remove_model, :toggle_table_column,
                                                     :set_model_offset, :inc_column_position, :decr_column_position,
                                                     :update_column_options]

    def query_generator_session
      @query_generator_session ||= QueryGeneratorSession.new(session)
    end

    def index
      @generated_queries = GeneratedQuery.paginate(:page => params[:page], :per_page => 50)
    end

    # Loads the wizard for a new generated query
    #--------------------------------------------------------------
    def new
      query_generator_session.reset!
      query_generator_session.generated_query = GeneratedQuery.new
      redirect_to query_generator_generated_query_wizard_path(:wizard_step => "main_model")
    end

    # Loads the wizard to edit a generated query
    # The wizard step can be specified with params[:step]
    #--------------------------------------------------------------
    def edit
      query_generator_session.reset!
      query_generator_session.generated_query = GeneratedQuery.find(params[:id])
      step = params[:step] || "main_model"
      redirect_to query_generator_generated_query_wizard_path(:wizard_step => step)
    end

    # Creates the query which is currently loaded by the wizard
    #--------------------------------------------------------------
    def create
      query_generator_session.update_query_attributes(params[:query_generator_generated_query])
      if query_generator_session.save_generated_query
        query_generator_session.reset!
        redirect_to query_generator_generated_queries_path
      else
        redirect_to :back
      end
    end

    # Saves the query which is currently loaded by the wizard
    #--------------------------------------------------------------
    def update
      query_generator_session.update_query_attributes(params[:query_generator_generated_query])
      if query_generator_session.save_generated_query
        query_generator_session.reset!
        redirect_to query_generator_generated_queries_path
      else
        redirect_to :back
      end
    end

    # Deletes the given query
    #--------------------------------------------------------------
    def destroy
      generated_query = QueryGenerator::GeneratedQuery.find(params[:id])
      if generated_query && ccan?(:destroy, generated_query)
        generated_query.destroy
      end
      redirect_to query_generator_generated_queries_path
    end

    # Executes the generated query
    # Pagination is automatically turned off when using the csv format
    # When fetching JSON without the DataTable plugin, you can use
    # params[:offset] and params[:per_page] to get the records you want.
    #--------------------------------------------------------------
    def show
      @generated_query = GeneratedQuery.find(params[:id])
      redirect_to :index unless ccan? :read, @generated_query

      respond_to do |format|
        format.html
        format.json {
          table_adapter = DataTableAdapter.new
          table_adapter.parse_params!(params)

          offset = table_adapter.offset || params[:offset] || 0
          per_page = table_adapter.per_page || params[:per_page] || 50

          #Test if the json was requested by the DataTable
          if table_adapter.has_data
            if @generated_query.set_custom_order(table_adapter.order_by_columns)
              flash.now[:notice] = "You have chosen a custom order."
            end
          end

          @records = @generated_query.execute(:offset => offset, :per_page => per_page)
        }
        format.csv {
          @records = @generated_query.execute(:no_pagination => true)
          render_csv(@generated_query.name + "_exported_" + Time.now.to_s)
        }
      end
      #@executed_query_rows = @generated_query.execute(:page => params[:page])
    end

    # The action to display the main wizard steps
    # The step to load is specified in params[:wizard_step] which
    # comes directly from the routes
    #--------------------------------------------------------------
    def wizard
      @wizard_step = WIZARD_STEPS.index(params[:wizard_step]) + 1

      #Make sure everything is set up for the current step. If not, redirect the user to the step he deserves.
      if @wizard_step > 1 && query_generator_session.main_model.nil?
        redirect_to query_generator_generated_query_wizard_path(:wizard_step => "main_model") and return
      end

      #Special values we need for some steps
      case @wizard_step
        when 2, 3
          @model_offsets = {}
          query_generator_session.used_models.each do |model|
            offsets = query_generator_session.model_offsets(model)
            @model_offsets[model_dom_id(model)] = offsets if offsets
          end
          @model_connections = []
          query_generator_session.model_associations.each do |model, associations|
            associations.each do |association_name, target|
              @model_connections << [model_dom_id(model, :include_hash => true), model_dom_id(target, :include_hash => true), association_name]
            end
          end
      end

      #As many methods from the GeneratedQuery model are used,
      #we need to keep it up to date
      query_generator_session.update_query_object
      query_generator_session.current_step = @wizard_step
    end

    #--------------------------------------------------------------
    #                       Wizard Actions
    #--------------------------------------------------------------

    #####################
    #### STEP 1
    #####################

    # Sets the main model for the generated query
    # Leads to the second wizard step
    #--------------------------------------------------------------
    def set_main_model
      if @model
        query_generator_session.main_model = @model
        query_generator_session.current_step = 2
        flash.now[:notice] = t("query_generator.wizard.main_model.success")
        redirect_to query_generator_generated_query_wizard_path(:wizard_step => "associations") and return
      end

      redirect_to :back
    end

    # Displays the model's records as a preview. Can be used
    # if the user is unsure what exactly the table contains
    #--------------------------------------------------------------
    def preview_model_records
      if @model
        @records = @model.paginate(:page => params[:page], :per_page => conf(:pagination)[:per_page])
      end

      respond_to do |format|
        format.js
      end
    end

    #####################
    #### STEP 2
    #####################

    # Adds a new association to the generated_query.
    # Params which come in are the following:
    #   :model       -- The model which already exists in the query
    #   :association -- The association name in :model to be added
    # If the mode which is the end point of the association does
    # not exist in the query yet, it is automatically added
    # (see query_generator_session)
    #--------------------------------------------------------------
    def add_association
      if @model
        @association = params[:association]
        @target = dh.graph.associations_for(@model)[@association]

        if ccan? :read, @target
          @model_added = query_generator_session.add_association(@model, params[:association], @target)
          flash.now[:notice] = t("query_generator.success.model_added", :model => human_model_name(@model))
        else
          flash.now[:error] = t("query_generator.errors.model_not_found_or_permissions", :model => (human_model_name(@target) || ""))
          @target = nil
        end
      end

      respond_to do |format|
        format.js
      end
    end

    # Removes a model from the generated query
    #--------------------------------------------------------------
    def remove_model
      if @model
        @removed_models = query_generator_session.remove_model(@model)
      end

      @model_offsets = {}
      query_generator_session.used_models.each do |model|
        offsets = query_generator_session.model_offsets(model)
        @model_offsets[model_dom_id(model)] = offsets if offsets
      end

      respond_to do |format|
        format.js
      end
    end

    # Toggles if a table column is used for the current query
    # Important: That does not mean that it will be displayed when
    #            the query is executed!
    # TODO: probably better test if it's an actual column...
    #--------------------------------------------------------------
    def toggle_table_column
      if @model
        column = params[:column]
        query_generator_session.toggle_used_column(@model, column)
      end

      respond_to do |format|
        format.js
      end
    end

    # Moves the given column to the right
    #--------------------------------------------------------------
    def inc_column_position
      if @model
        query_generator_session.change_column_position(@model, params[:column], 1)
      end

      respond_to do |format|
        format.js {render wizard_file(4, "update_columns_table")}
      end
    end

    # Moves the given column to the left
    #--------------------------------------------------------------
    def decr_column_position
      if @model
        query_generator_session.change_column_position(@model, params[:column], -1)
      end

      respond_to do |format|
        format.js {render wizard_file(4, "update_columns_table")}
      end
    end

    # Method to update most of the column options by passing it
    # to the QueryColumn object which takes care of possible conversions
    #--------------------------------------------------------------
    def update_column_options
      if @model
        column = params[:column]
        option = params[:option]
        value = params[:options][option] rescue nil

        query_generator_session.update_column_options(@model, column, option => value)
      end

      respond_to do |format|
        format.js {render wizard_file(4, "update_columns_table")}
      end
    end


    # Saves the model box offset for later use
    #--------------------------------------------------------------
    def set_model_offset
      if @model
        offset_top = params[:offset].first.to_i
        offset_left = params[:offset].last.to_i
        query_generator_session.set_model_offset(@model, offset_top, offset_left)
      end

      render :nothing => true
    end

    # Sets how the wizard progress should be displayed
    #--------------------------------------------------------------
    def set_progress_view
      query_generator_session.progress_view = params[:progress_view] if params[:progress_view]
      render :nothing => true
    end

    private

    include QueryGenerator::HelperFunctions

    # Tries to get the model from params and checks if the current
    # user has the necessary permissions to read its records
    # It automatically sets the instance variable @models and creates
    # a flash error message if the model couldn't be loaded for some reason
    #--------------------------------------------------------------
    def load_model_from_params
      @model = params[:model].classify.constantize rescue nil
      @model ||= params[:model].classify.pluralize.constantize rescue nil #Models in plural... bad naming

      if @model.nil? || !ccan?(:read, @model)
        flash.now[:error] = t("query_generator.errors.model_not_found_or_permissions", :model => (human_model_name(@model) || params[:model]))
        @model = nil
      end
    end

    # Shortcut to get the DataHolder instance
    #--------------------------------------------------------------
    def dh
      return @dh if @dh
      QueryGenerator::Configuration.set(:exclusions, :classes => [Audit, Page, Sheet, SheetLayout, Attachment], :modules => [Tolk])
      @dh = DataHolder
    end

    # A shortcut to get a QueryGenerator::Configuration
    #--------------------------------------------------------------
    def conf(config_name)
      QueryGenerator::Configuration.get(config_name)
    end

    # Just a shortcut to get the correct file name
    #--------------------------------------------------------------
    def wizard_file(step, file_name)
      "query_generator/generated_queries/wizard/step_#{step}/#{file_name}"
    end

    # Creates a dom_id for a model. Reason: see association_dom_id()
    #--------------------------------------------------------------
    def model_dom_id(model, options = {})
      handle_dom_id_options("model_#{model.to_s.underscore}", options)
    end

    # Parses the general options for all xx_dom_id() functions
    #--------------------------------------------------------------
    def handle_dom_id_options(res, options)
      res = [options[:prefix], res].join("_") if options[:prefix]
      res = [res, options[:suffix]].join("_") if options[:suffix]
      options[:include_hash] ? "#" + res : res
    end

    # Helper method to set the necessary headers for CSV exports
    #--------------------------------------------------------------
    def render_csv(filename = nil)
      filename ||= params[:action]
      filename.gsub!(/[ \&\:\+]/, "_")
      filename += '.csv'

      if request.env['HTTP_USER_AGENT'] =~ /msie/i
        headers['Pragma'] = 'public'
        headers["Content-type"] = "text/plain"
        headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
        headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
        headers['Expires'] = "0"
      else
        headers["Content-Type"] ||= 'text/csv'
        headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
      end

      render :layout => false
    end

  end
end