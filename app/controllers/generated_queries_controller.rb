class GeneratedQueriesController < ApplicationController

  layout "rails_query_generator"

  def index
    @dh = QueryGenerator::DataHolder.instance
  end
end
