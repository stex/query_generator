module QueryGenerator

  class GeneratedQuery < ActiveRecord::Base
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    validates_presence_of :name
    validates_presence_of :main_model

    serialize :models, Array
    serialize :associations, Hash
    serialize :model_offsets, Hash
    serialize :columns, Array

    def join_method
      :joins
    end

    # Returns an array of string which contains all column names
    # for output
    #--------------------------------------------------------------
    def table_header_columns
      output_columns.map &:name
    end

    def execute(options = {})
      per_page = options.delete(:per_page) || 50
      page = options[:page] || 1

      query = {}
      joins = joins_for(main_model_object, false)
      query[join_method] = joins if joins && joins.any?
      query[:order] = order_by unless order_by.blank?
      query[:group] = "#{main_model_object.table_name}.#{main_model_object.primary_key}"

      main_records = main_model_object.find(:all, query)

      rows = []
      main_records.each do |record|
        rows += build_rows_for(record)
      end

      rows = rows.reject {|r| r.include?(nil)}

      rows.paginate(:page => page, :per_page => per_page)
    end

    # If the given record or one of its associations has a has_many
    # association, we have to add additional rows to the result set
    # TODO:
    #    1. Find a better solution than looping over all rows again for joins
    #    2. Joins müssen weitergegeben werden, um unzutreffende sachen rauszufiltern (wenn das set leer ist. :include unterstützen?)
    #    3. :order muss weitergegeben werden, ansonsten werden order by klauseln in den associations nicht berücksichtigt
    #    4. :conditions müssen weitergegeben werden
    #
    #    bei 3. und 4. muss berücksichtigt werden, dass die bereits genutzten einträge (resp. welche, die nicht mit der aktuellen abfrage
    ##               übereinstimmen, gelöscht werden.)

    # parameters
    #   followed_association: die association, die vom vorherigen
    #                         zum jetzigen record geführt hat. Wird für das filtern der joins benötigt
    #--------------------------------------------------------------
    def build_rows_for(record)
      model = record.class
      rows = model_associations_for(model).any? ? [] : [Array.new(output_columns.size)]

      model_associations_for(model).each do |association, target|
        follow_association(record, association, target, :joins => joins_for(target)) do |association_record|
          rows += build_rows_for(association_record)
        end
      end

      columns = output_columns

      rows.each do |row|
        columns.each_index do |index|
          if columns[index].model == model
            value = record.send(columns[index].column_name)
            row[index] = value || ""
          end
        end
      end

      rows = merge_arrays_by_index(rows)
      rows.uniq.compact
    end


    def merge_arrays_by_index(arrays)
      unless arrays.empty?
        highest_index = arrays.first.size - 1

        (0..highest_index).each do |index|
          unique_value = unique_value_at?(arrays, index)
          if unique_value
            arrays.map {|a| a[index] = unique_value}
          end
        end
      end

      arrays
    end

    # Checks, if all given arrays have the same value or nil at the given position
    # Returns the value if +true+, -false- otherwise
    #--------------------------------------------------------------
    def unique_value_at?(arrays, index)
      value = nil
      arrays.each do |array|
        value ||= array[index]
        return false if array[index] && array[index] != value
      end

      value
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

    def model_associations_for(model)
      model_associations[model] || {}
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
    # The pretty_mode switch will remove some (for reading) unnecessary brackets
    #--------------------------------------------------------------
    def joins_for(model, pretty_mode = false)
      joins = []
      #Test if there is at least one association for the given model
      if model_associations[model].present? && model_associations[model].any?
        association_amount = model_associations[model].size
        model_associations[model].each do |association, target|
          if is_end_association?(model, association)
            if association_amount == 1 && pretty_mode
              return association.to_sym
            else
              joins << association.to_sym
            end
          else
            if association_amount == 1 && pretty_mode
              return {association => joins_for(target)}
            else
              joins << {association.to_sym => joins_for(target)}
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

    # Follows the given association with options and yields all found
    # records.
    # Options are e.g. additional conditions and joins. These are only
    # used for x..n-associations as x..1 are already handled by the main model find()
    #--------------------------------------------------------------
    def follow_association(record, association, target, options = {})
      model = record.class
      association_options = DataHolder.graph.association_options(model, association)

      query = {}
      query[join_method] = options[:joins] if options[:joins]
      query[:group] = "#{target.table_name}.#{target.primary_key}"# if options[:joins]

      #a :1 association
      if [:belongs_to, :has_one].include?(association_options[:macro])
        yield record.send(association)
      else
        record.send(association).find(:all, query).each do |association_record|
          yield association_record
        end
      end
    end
  end
end