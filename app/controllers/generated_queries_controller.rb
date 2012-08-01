class GeneratedQueriesController < ApplicationController
  unloadable if Rails.env.development?

  include QueryGenerator

  #Set the layout based on the current configuration
  layout QueryGenerator::Configuration.get(:controller)[:layout]

  #Make the query_generator_session available in views
  helper_method :query_generator_session

  #Load the DataHolder for methods which need it.
  before_filter :load_data_holder_instance, :only => [:new, :edit, :add_model]

  def query_generator_session
    @query_generator_session ||= QueryGenerator::QueryGeneratorSession.new(session)
  end

  def index
    @generated_queries = GeneratedQuery.all.paginate(:page => params[:page], :per_page => 50)
  end

  def new
    @generated_query = GeneratedQuery.new
    query_generator_session.init_for_generated_query(@generated_query)
  end

  def edit
    @generated_query = Generated_query.find(params[:id])
  end

  # Adds a new model node to the currently edited GeneratedQuery.
  # This happens only in the session, so nothing is saved yet.
  #                                                          AJAX
  #--------------------------------------------------------------
  def add_model
    @model = params[:model].try(:constantize)
    if @model && ccan?(:read, @model)
      query_generator_session.add_model(@model)
      flash.now[:notice] = "Added model"
    else
      flash.now[:error] = "Model does not exist or you don't have the necessary rights to access it."
      @model = nil
    end

    respond_to do |format|
      format.js
    end
  end


  private

  include QueryGenerator::HelperFunctions

  def load_data_holder_instance
    @dh = QueryGenerator::DataHolder.instance
    QueryGenerator::Configuration.set(:exclusions, :classes => [Audit, Page, Sheet, SheetLayout, Attachment], :modules => [Tolk])
  end
end
