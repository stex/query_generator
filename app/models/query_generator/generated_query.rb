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
      output_columns.map {|oc| [oc.full_column_name.sub(".", "_"), oc.name]}
    end

    def sql(options = {})
      what = options.delete(:what) || build_columns
      sql = main_model_object.view_sql(:all, build_query(main_model_object, options))
      sql = sql.gsub(/SELECT (.*) FROM/, "SELECT #{what} FROM")
    end

    def sql_lines
      sql.split(/(FROM)|(INNER JOIN)|(JOIN)|(ORDER BY)|(WHERE)/)
    end

    def build_columns
      cols = []
      output_columns.each do |qc|
        cols << "#{qc.full_column_name} AS `#{qc.full_column_name}`"
      end
      cols.join(", ")
    end

    def build_query(record, options = {})
      query = {}
      joins = joins_for(record)
      joins = [joins] if joins && !joins.is_a?(Array)
      query[join_method] = joins if joins && joins.any?
      query[:order] = order_by if order_by.present?
      query[:limit] = options[:limit] if options[:limit]
      query[:offset] = options[:offset] if options[:offset]
      query
    end

    def default_query
      if main_model
        build_query(main_model_object)
      else
        {}
      end
    end
    
    # Calculates the row amount this query will produce
    # This is pure SQL and can be used to confirm that the correct
    # amount of rows is returned by .execute
    #--------------------------------------------------------------
    def count
      main_model_object.connection.select_all(sql(:what => "COUNT(*)")).first.values.first.to_i
    end

    def execute(options = {})
      sql_options = {}

      unless options[:no_pagination]
        #will_paginate cannot be used here, so we
        #have to create our own pagination
        sql_options[:limit] = (options.delete(:per_page) || 50).to_i
        sql_options[:offset] = options.delete(:offset).to_i
      end

      #Pagination can go back in once the methods for generating custom SQL are in place
      query = sql(sql_options)

      joined_records = main_model_object.connection.select_all(query)
      rows = []
      joined_records.each do |jr|
        row = Array.new(output_columns.size)
        output_columns.each_index do |index|
          row[index] = jr[output_columns[index].full_column_name]
        end
        rows << row
      end

      rows


      #query = build_query(main_model_object, options)
      #main_records = main_model_object.find(:all, query)
      #
      #rows = []
      #main_records.each do |record|
      #  record_rows = build_rows_for(record)
      #  record_rows = record_rows.reject {|r| r.include?(nil)}
      #  rows += record_rows
      #end
      #rows
    end

    # If the given record or one of its associations has a has_many
    # association, we have to add additional rows to the result set
    # TODO:
    #    1. Find a better solution than looping over all rows again for joins
    #    2. Joins müssen weitergegeben werden, um unzutreffende sachen rauszufiltern (wenn das set leer ist. :include unterstützen?)
    #    4. :conditions müssen weitergegeben werden
    #
    #    bei 3. und 4. muss berücksichtigt werden, dass die bereits genutzten einträge (resp. welche, die nicht mit der aktuellen abfrage
    ##               übereinstimmen, gelöscht werden.)

    # parameters
    #   followed_association: die association, die vom vorherigen
    #                         zum jetzigen record geführt hat. Wird für das filtern der joins benötigt
    #--------------------------------------------------------------
    def build_rows_for(record, options = {})
      model = record.class
      rows = model_associations_for(model).any? ? [] : [Array.new(output_columns.size)]

      model_associations_for(model).each do |association, target|
        follow_association(record, association, target, :joins => joins_for(target)) do |association_record|
          rows += build_rows_for(association_record, options)
        end
      end

      columns = output_columns
      rows.each do |row|
        columns.each_index do |index|
          if columns[index].model == model
            if options[:return_records]
              row[index] = record
            else
              value = record.send(columns[index].column_name)
              row[index] = value || ""
            end
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
      return @model_associations if @model_associations
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

    def reset_instance_variables
      @model_associations = nil
      @used_columns = nil
      @output_columns = nil
    end

    # Returns all selected columns for the currently managed generated query
    # Format: [Column1, Column2, Column3]
    #--------------------------------------------------------------
    def used_columns
      @used_columns ||= columns.map {|c| QueryColumn.new(c)}
    end

    # Returns all columns to be included into the output table
    #--------------------------------------------------------------
    def output_columns
      @output_columns ||= used_columns.select {|uc| uc.output }
    end

    # Sets a custom order temporarily (for the request)
    # It accepts an array of custom columns in the format
    # [[column_1_index, "sort_direction"], [...], ...]
    # returns +true+ if the order is indeed custom
    #--------------------------------------------------------------
    def set_custom_order(custom_columns = [])
      current_order = used_columns.map {|uc| [uc.position, uc.order] if uc.order}.compact

      used_columns.each do |uc|
        uc.order = nil
      end

      custom_columns.each do |column_sorting|
        used_columns[column_sorting.first].order = column_sorting.last
      end

      current_order != custom_columns
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
              return association.to_sym
            else
              joins << association.to_sym
            end
          else
            if association_amount == 1
              return {association.to_sym => joins_for(target)}
            else
              joins << {association.to_sym => joins_for(target)}
            end
          end
        end
      end
      joins
    end

    def to_s(options = {})
      options.reverse_merge!({:joins => true, :order => true})

      result = ""

      if main_model
        query = build_query(main_model_object, :pretty_inspect => true, :order_by => true)
        result = %{#{main_model}.find(:all, #{query.pretty_inspect})}
      end

      result
    end

    # Returns all columns marked for output
    #--------------------------------------------------------------
    def output_columns
      used_columns.select {|qc| qc.output }
    end

    # Generates the necessary javascript options for the DataTables plugin
    #--------------------------------------------------------------
    def table_js
      result = {}
      result["aaSorting"] = []
      used_columns.each_index do |index|
        uc = used_columns[index]
        next unless uc.order
        result["aaSorting"] << [index, uc.order]
      end

      result
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

      #Build joins and group_by statement
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