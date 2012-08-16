module QueryGenerator

  class GeneratedQuery < ActiveRecord::Base

    validates_presence_of :name

    serialize :associations, Hash
    serialize :values, Hash
  end
end