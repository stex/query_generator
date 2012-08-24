class GeneratedQueriesController < ApplicationController
  unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

  #Set the layout based on the current configuration
  layout QueryGenerator::Configuration.get(:controller)[:layout]

  #Make the query_generator_session available in views
  helper_method :query_generator_session, :conf, :dh, :human_model_name, :wizard_file, :model_dom_id, :handle_dom_id_options

  #Load the requested model from params
  before_filter :load_model_from_params, :only => [:add_association, :preview_model_records,
                                                   :set_main_model, :remove_model, :toggle_table_column,
                                                   :set_model_offset, :inc_column_position, :decr_column_position,
                                                   :update_column_options]

  def query_generator_session
    @query_generator_session ||= QueryGenerator::QueryGeneratorSession.new(session)
  end

  def index
    @generated_queries = QueryGenerator::GeneratedQuery.paginate(:page => params[:page], :per_page => 50)
  end

  # TODO: Check if there is an unfinished query in the session and reload it.
  #--------------------------------------------------------------
  def new
    query_generator_session.reset!
    query_generator_session.generated_query = QueryGenerator::GeneratedQuery.new
    redirect_to query_generator_generated_query_wizard_path(:wizard_step => "main_model")
  end

  def edit
    query_generator_session.reset!
    query_generator_session.generated_query = QueryGenerator::GeneratedQuery.find(params[:id])
    redirect_to query_generator_generated_query_wizard_path(:wizard_step => "main_model")
  end

  def create
    query_generator_session.update_query_attributes(params[:query_generator_generated_query])
    if query_generator_session.save_generated_query
      query_generator_session.reset!
      redirect_to query_generator_generated_queries_path
    else
      redirect_to :back
    end
  end

  def update
    query_generator_session.update_query_attributes(params[:query_generator_generated_query])
    if query_generator_session.save_generated_query
      query_generator_session.reset!
      redirect_to query_generator_generated_queries_path
    else
      redirect_to :back
    end
  end

  def destroy
    generated_query = QueryGenerator::GeneratedQuery.find(params[:id])
    if generated_query && ccan?(:destroy, generated_query)
      generated_query.destroy
    end
  end

  def show

  end

  # The action to display the main wizard steps
  #--------------------------------------------------------------
  def wizard
    @wizard_step = QueryGenerator::WIZARD_STEPS.index(params[:wizard_step]) + 1

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

    render :nothing => true
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
      @target = dh.linkage_graph.get_node(@model).get_model_by_association(params[:association])
      @association = params[:association]

      if ccan? :read, @target
        @model_added = query_generator_session.add_association(@model, params[:association])
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

  private

  include QueryGenerator::HelperFunctions

  def set_step_direction(direction)
    @step_direction = direction
  end

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
    #QueryGenerator::Configuration.set(:exclusions, :classes => [Audit, Page, Sheet, SheetLayout, Attachment], :modules => [Tolk])
    @dh = QueryGenerator::DataHolder.instance
  end

  # A shortcut to get a configuration
  #--------------------------------------------------------------
  def conf(config_name)
    QueryGenerator::Configuration.get(config_name)
  end

  # Just a shortcut to get the correct file name
  #--------------------------------------------------------------
  def wizard_file(step, file_name)
    "generated_queries/wizard/step_#{step}/#{file_name}"
  end

  # Creates a dom_id for a model. Reason: see association_dom_id()
  #--------------------------------------------------------------
  def model_dom_id(model, options = {})
    handle_dom_id_options("model_#{model.to_s.underscore}", options)
  end

  def handle_dom_id_options(res, options)
    res = [options[:prefix], res].join("_") if options[:prefix]
    res = [res, options[:suffix]].join("_") if options[:suffix]
    options[:include_hash] ? "#" + res : res
  end
end
