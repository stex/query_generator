class GeneratedQueriesController < ApplicationController

  layout "rails_query_generator"
  include QueryGenerator

  def index
    @generated_queries = GeneratedQuery.all
    @dh = QueryGenerator::DataHolder.instance
    render :action => :linkage_graph
  end

  def linkage_wheel
    @dh = QueryGenerator::DataHolder.instance
  end
end
