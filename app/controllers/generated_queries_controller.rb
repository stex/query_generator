class GeneratedQueriesController < ApplicationController

  layout "rails_query_generator"
  include QueryGenerator::HelperFunctions

  def index
    @generated_queries = GeneratedQuery.all
  end

  def linkage_wheel
    @dh = QueryGenerator::DataHolder.instance
  end
end
