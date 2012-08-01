module QueryGenerator

  class GeneratedQuery < ActiveRecord::Base

    serialize :query, Hash

  end
end