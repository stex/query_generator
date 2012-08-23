module QueryGenerator

  class GeneratedQuery < ActiveRecord::Base

    validates_presence_of :name
    validates_presence_of :main_model

    serialize :models, Array
    serialize :associations, Hash
    serialize :model_offsets, Hash
    serialize :columns, Hash
  end
end