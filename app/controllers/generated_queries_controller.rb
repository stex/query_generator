class GeneratedQueriesController < ApplicationController
  unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

  #Set the layout based on the current configuration
  layout QueryGenerator::Configuration.get(:controller)[:layout]

  #Make the query_generator_session available in views
  helper_method :query_generator_session, :conf, :dh, :current_step, :human_model_name

  #Load the requested model from params
  before_filter :load_model_from_params, :only => [:add_association, :preview_model_records,
                                                   :set_main_model, :remove_model, :toggle_table_column,
                                                   :set_model_offset]

  def query_generator_session
    @query_generator_session ||= QueryGenerator::QueryGeneratorSession.new(session)
  end

  def index
    @generated_queries = QueryGenerator::GeneratedQuery.paginate(:page => params[:page], :per_page => 50)
  end

  # TODO: Check if there is an unfinished query int he session and reload it.
  #--------------------------------------------------------------
  def new
    @generated_query = QueryGenerator::GeneratedQuery.new
    query_generator_session.init_for_generated_query(@generated_query)
  end

  def edit
    @generated_query = QueryGenerator::Generated_query.find(params[:id])
  end

  #--------------------------------------------------------------
  #                       Wizard Actions
  #--------------------------------------------------------------

  # Loads the previous wizard step.
  # At the moment this is just opening the chosen accordion slide,
  # but additional things might come im handy here.
  #--------------------------------------------------------------
  def load_previous_wizard_step
    @current_step = params[:current].to_i - 1

    respond_to do |format|
      format.js
    end
  end

  #####################
  #### STEP 1
  #####################

  # Sets the main model for the generated query
  # Leads to the second wizard step
  #--------------------------------------------------------------
  def set_main_model
    if @model
      #Check if there was an old main_model set. If yes and the new one is different,
      #delete the chosen associations and values
      if query_generator_session.main_model != @model
        query_generator_session.reset(:associations)
        query_generator_session.reset(:values)
        query_generator_session.reset(:model_offsets)
        @main_model_changed = true
      end

      query_generator_session.main_model = @model
      flash.now[:notice] = t("query_generator.wizard.main_model.success")

      set_step_direction(:forward)
    end

    respond_to do |format|
      format.js {render :template => "generated_queries/wizard_2a/step_switch.js.rjs"}
    end
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

  # Replaces the column boxes with the association_boxes
  #--------------------------------------------------------------
  def choose_model_associations
    respond_to do |format|
      format.js {render "toggle_model_boxes"}
    end
  end

  # Replaces the association boxes with model columns
  # to let the user choose the columns he'd like to use in the
  # query
  #--------------------------------------------------------------
  def choose_model_columns
    @columns = true

    respond_to do |format|
      format.js {render "toggle_model_boxes"}
    end
  end

  # Leads to the third wizard step
  #--------------------------------------------------------------
  def set_conditions
    query_generator_session.reset(:model_offsets)

    #Save the model box offsets
    params[:offsets].each do |key, offset_array|
      model = key.sub("model_", "").classify
      offset_top = offset_array.first.to_i
      offset_left = offset_array.last.to_i
      query_generator_session.set_model_offset(model, offset_top, offset_left)
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

  def current_step
    return @current_step if @current_step

    @current_step = case params[:action].to_s
                       when "new"
                         1
                       when "set_main_model", "add_association", "remove_model"
                         2
                       else
                         3

                     end
  end

  # Tries to get the model from params and checks if the current
  # user has the necessary permissions to read its records
  # It automatically sets the instance variable @models and creates
  # a flash error message if the model couldn't be loaded for some reason
  #--------------------------------------------------------------
  def load_model_from_params
    @model = params[:model].classify.constantize rescue nil

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
end
