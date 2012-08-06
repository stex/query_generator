class GeneratedQueriesController < ApplicationController
  unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

  #Set the layout based on the current configuration
  layout QueryGenerator::Configuration.get(:controller)[:layout]

  #Make the query_generator_session available in views
  helper_method :query_generator_session, :conf

  #Load the DataHolder for methods which need it.
  before_filter :load_data_holder_instance, :only => [:new, :edit, :add_model]

  #Load the requested model from params
  before_filter :load_model_from_params, :only => [:add_model, :preview_model_records]

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

  # Adds a new model node to the currently edited GeneratedQuery.
  # This happens only in the session, so nothing is saved yet.
  #                                                          AJAX
  #--------------------------------------------------------------
  def add_model
    if @model
      query_generator_session.add_model(@model)
      flash.now[:notice] = t("query_generator.success.model_added", :model => @model.human_name)
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
  # a flash error message
  #--------------------------------------------------------------
  def load_model_from_params
    @model = params[:model].try(:constantize)

    if @model.nil? || !ccan?(:read, @model)
      flash.now[:error] = t("query_generator.errors.model_not_found_or_permissions", :model => (@model.try(:human_name) || params[:model]))
      @model = nil
    end
  end

  def load_data_holder_instance
    @dh = QueryGenerator::DataHolder.instance
    QueryGenerator::Configuration.set(:exclusions, :classes => [Audit, Page, Sheet, SheetLayout, Attachment], :modules => [Tolk])
  end

  # A shortcut to get a configuration
  #--------------------------------------------------------------
  def conf(config_name)
    QueryGenerator::Configuration.get(config_name)
  end
end
