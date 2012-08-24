module QueryGenerator

  class GeneratedQuery < ActiveRecord::Base
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    validates_presence_of :name
    validates_presence_of :main_model

    serialize :models, Array
    serialize :associations, Hash
    serialize :model_offsets, Hash
    serialize :columns, Array

    # Returns all associations
    # Format:
    # {SourceModel => {:association => TargetModel}}
    #--------------------------------------------------------------
    def model_associations
      #return @model_associations if @model_associations
      @model_associations = {}

      associations.each do |source, associations|
        source_model = source.constantize
        associations.each do |association, target|
          @model_associations[source_model] ||= HashWithIndifferentAccess.new
          @model_associations[source_model][association] = target.constantize
        end
      end
      @model_associations
    end

    # Returns all selected columns for the currently managed generated query
    # Format: [Column1, Column2, Column3]
    #--------------------------------------------------------------
    def used_columns
      @used_columns = columns.map {|c| QueryColumn.new(c)}
    end

    # Returns all columns to be included into the output table
    #--------------------------------------------------------------
    def output_columns
      @output_columns = used_columns.select {|uc| uc.output }
    end

    # Generates the ":order => """ part of a query
    #--------------------------------------------------------------
    def order_by
      order = []
      used_columns.each do |qc|
        order << qc.order_by_string if qc.order
      end
      order.join(", ")
    end

    # Recursive function to build the joins array based on
    # the used associations.
    # If a model only has one association, the array around
    # it will be removed for better readability
    #--------------------------------------------------------------
    def joins_for(model)
      joins = []
      #Test if there is at least one association for the given model
      if model_associations[model].present? && model_associations[model].any?
        association_amount = model_associations[model].size
        model_associations[model].each do |association, target|
          if is_end_association?(model, association)
            if association_amount == 1
              return association
            else
              joins << association
            end
          else
            if association_amount == 1
              return {association => joins_for(target)}
            else
              joins << {association => joins_for(target)}
            end
          end
        end
      end
      joins
    end

    private

    # Tests if this is the end of an association chain
    #--------------------------------------------------------------
    def is_end_association?(model, association)
      target = model_associations[model][association]
      model_associations[target].nil?
    end

  end
end