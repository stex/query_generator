module QueryGenerator

  class GeneratedQuery < ActiveRecord::Base
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    validates_presence_of :name
    validates_presence_of :main_model

    serialize :models, Array
    serialize :associations, Hash
    serialize :model_offsets, Hash
    serialize :columns, Array

    # Returns an array of string which contains all column names
    # for output
    #--------------------------------------------------------------
    def table_header_columns
      output_columns.map &:name
    end

    def execute
      query = {}
      joins = joins_for(main_model_object)
      query[:include] = joins if joins && joins.any?
      query[:order] = order_by unless order_by.blank?

      main_records = main_model_object.find(:all, query)
      rows = []
      main_records.each do |record|
        rows += build_rows_for(record)
      end

      rows
    end

    # If the given record or one of its associations has a has_many
    # association, we have to add additional rows to the result set
    #--------------------------------------------------------------
    def build_rows_for(record)
      rows = [Array.new(output_columns.size)]
      model = record.class

      model_node = QueryGenerator::DataHolder.instance.linkage_graph.get_node(model)

      model_associations[model].each do |association, target|
        association_options = model_node.get_association_options(association)

        #a :1 association
        if [:belongs_to, :has_one].include?(association_options[:macro])
          rows += build_rows_for(record.send(association))
        else #a :n association
          record.send(association).each do |association_record|
            rows += build_rows_for(association_record)
          end
        end
      end

      columns = output_columns

      rows.each do |row|
        columns.each_index do |index|
          if columns[index].model == model
            row[index] = record.send(columns[index].column_name)
          end
        end
      end

      rows
    end




    # Returns the constantized main_model
    #--------------------------------------------------------------
    def main_model_object
      main_model.constantize
    end

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