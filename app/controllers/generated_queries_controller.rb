class GeneratedQueriesController < ApplicationController
  unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

  #Set the layout based on the current configuration
  layout QueryGenerator::Configuration.get(:controller)[:layout]

  #Make the query_generator_session available in views
  helper_method :query_generator_session, :conf, :dh

  #Load the requested model from params
  before_filter :load_model_from_params, :only => [:add_association, :preview_model_records, :set_main_model]

  def query_generator_session
    @query_generator_session ||= QueryGenerator::QueryGeneratorSession.new(session)
  end

  def index
    @generated_queries = QueryGenerator::GeneratedQuery.all.paginate(:page => params[:page], :per_page => 50)
  end

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
      @end_point = dh.linkage_graph.get_node(@model).get_model_by_association(params[:association])
      @association = params[:association]

      if ccan? :read, @end_point
        @model_added = query_generator_session.add_association(@model, params[:association])
        flash.now[:notice] = t("query_generator.success.model_added", :model => @model.human_name)
      else
        flash.now[:error] = t("query_generator.errors.model_not_found_or_permissions", :model => (@end_point.try(:human_name) || ""))
        @end_point = nil
      end
    end

    respond_to do |format|
      format.js
    end
  end

  # Sets the main model for a generated query
  #--------------------------------------------------------------
  def set_main_model
    if @model
      query_generator_session.main_model = @model
      flash.now[:notice] = t("query_generator.wizard.main_model.success")
    end

    respond_to do |format|
      format.js
    end
  end

  private

  include QueryGenerator::HelperFunctions

  # Tries to get the model from params and checks if the current
  # user has the necessary permissions to read its records
  # It automatically sets the instance variable @models and creates
  # a flash error message if the model couldn't be loaded for some reason
  #--------------------------------------------------------------
  def load_model_from_params
    @model = params[:model].try(:constantize)

    if @model.nil? || !ccan?(:read, @model)
      flash.now[:error] = t("query_generator.errors.model_not_found_or_permissions", :model => (@model.try(:human_name) || params[:model]))
      @model = nil
    end
  end

  # Shortcut to get the DataHolder instance
  #--------------------------------------------------------------
  def dh
    QueryGenerator::Configuration.set(:exclusions, :classes => [Audit, Page, Sheet, SheetLayout, Attachment], :modules => [Tolk])
    QueryGenerator::DataHolder.instance
  end

  # A shortcut to get a configuration
  #--------------------------------------------------------------
  def conf(config_name)
    QueryGenerator::Configuration.get(config_name)
  end
end
