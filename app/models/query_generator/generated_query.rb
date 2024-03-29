module QueryGenerator

  class GeneratedQuery < ActiveRecord::Base
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    validates_presence_of :name
    validates_presence_of :main_model

    serialize :models, Array
    serialize :associations, Hash
    serialize :model_offsets, Hash
    serialize :columns, Array

    def join_method; :joins end

    #--------------------------------------------------------------
    #      Getter functions which will set the default values
    #--------------------------------------------------------------

    def get_name
      self.name
    end

    def get_main_model
      self.main_model
    end

    def constantized_main_model
      get_main_model.constantize rescue nil
    end

    def get_models
      self.models ||= []
    end

    def uses_model?(model)
      get_models.include?(model.to_s)
    end

    def constantized_models
      @constantized_models ||= get_models.map(&:constantize)
    end

    def get_associations
      self.associations ||= {}
    end

    def associations_for(model)
      get_associations[model.to_s] || {}
    end

    # Returns all models which are the target of at least one association
    #--------------------------------------------------------------
    def association_targets
      result = []
      get_associations.each do |source_name, association_targets|
        result += association_targets.values
      end
      result.uniq.compact
    end

    def get_model_offsets
      self.model_offsets ||= {}
    end

    def get_model_offsets_for_step(step)
      get_model_offsets[step] ||= {}
    end

    def get_columns
      self.columns ||= []
    end

    # Returns an array of string which contains all column names
    # for output
    #--------------------------------------------------------------
    def table_header_columns(delimiter = "_")
      output_columns.map {|oc| [oc.full_column_name(delimiter), oc.name]}
    end

    # Returns the SQL generated for the ORDER BY part
    #--------------------------------------------------------------
    def order_by_sql
      order_by
    end

    #--------------------------------------------------------------
    #                     SQL GENERATION
    #--------------------------------------------------------------

    # Returns all models which are not part of a join and therefore
    # have to be added to the query manually.
    # Only models which are actually used in the query will be added
    # This means, models which have associations to another model,
    # have columns which are marked
    # as output, have conditions or are part of a condition
    #--------------------------------------------------------------
    def independent_models
      joined_models = []
      get_associations.each do |source, association_targets|
        joined_models += association_targets.values
      end

      (get_models - joined_models - [main_model]).map(&:constantize).select {|model|
        #Check if the model has outgoing associations
        get_associations[model.to_s] && get_associations[model.to_s].any? ||
        #Check if the model has at least one column which is marked for output
        used_columns.detect {|qc| qc.model == model && qc.output } ||
        #Check if there is at least on valid condition for any column of this model
        used_columns.detect {|qc| qc.model == model && qc.valid_conditions.any? }
      }
    end

    # Returns the query as SQL generated by ActiveRecord
    # Options:
    #   :what      -- The SELECT part for the query. Defaults to all output columns
    #   other options: See build_query()
    # It will also add models without any associations to other models
    # as INNER JOINs without conditions to get the cross product
    #--------------------------------------------------------------
    def sql(options = {})
      what = options.delete(:what) || build_columns
      sql = main_model_object.view_sql(:all, build_query( options))
      independent_joins = independent_models.map {|im| "INNER JOIN `#{im.table_name}`"}
      sql.sub(/SELECT .* FROM ([\`]{0,1}[a-zA-Z\-\_\.]*[\`]{0,1})/, 'SELECT ' + what + ' FROM \1 ' + independent_joins.join(" "))
    end

    def sql_lines(options = {})
      sql(options).split(/(FROM)|(INNER JOIN)|(JOIN)|(ORDER BY)|(WHERE)/)
    end

    # Builds the output columns with complete names (table_name.column_name)
    #--------------------------------------------------------------
    def build_columns(options = {})
      custom_names = options.delete(:custom_names)
      cols = []
      output_columns.each do |qc|
        as = custom_names ? qc.name : qc.full_column_name
        cols << "#{qc.full_column_name(".", true)} AS `#{as}`"
      end
      cols.join(", ")
    end

    # Builds the query in ActiveRecord::Base.find()-Format
    # Arguments:
    #   Options:
    #     :limit     -- Amount of rows to be returned
    #     :offset    -- Row to start with
    #--------------------------------------------------------------
    def build_query(options = {})
      query = {}
      joins = joins_for(main_model_object)
      joins = [joins] if joins && !joins.is_a?(Array)
      conditions = build_conditions(options[:variables])
      query[join_method] = joins if joins && joins.any?
      query[:order] = order_by if order_by.present?
      query[:limit] = options[:limit] if options[:limit]
      query[:offset] = options[:offset] if options[:offset]
      query[:conditions] = conditions if conditions.any?
      query[:group] = group_by if group_by.present?
      query
    end

    # Calculates the row amount this query will produce
    # This is pure SQL and can be used to confirm that the correct
    # amount of rows is returned by .execute
    #--------------------------------------------------------------
    def count
      res = main_model_object.connection.select_all(sql(:what => "COUNT(1)"))
      res.size > 1 ? res.size : res.first.values.first.to_i
    end

    # Executes the current query and returns all columns which
    # are marked for output for each fetched record
    # Options:
    #   :no_pagination     -- If set to +true+, all records which
    #                         match the current query are returned
    #   :per_page          -- Row amount to be returned
    #   :offset            -- Row to start output with ((page - 1) * per_page)
    #--------------------------------------------------------------
    def execute(options = {})
      sql_options = {}

      unless options[:no_pagination]
        #will_paginate cannot be used here, so we
        #have to create our own pagination
        sql_options[:limit] = (options.delete(:per_page) || Configuration.get(:pagination)[:per_page]).to_i
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

    # Resets all cached values. This is necessary as the
    # methods from this model are used to display data
    # in the query wizard which might change during the request
    #--------------------------------------------------------------
    def reset_instance_variables
      @model_associations = nil
      @used_columns = nil
      @output_columns = nil
      @constantized_models = nil
    end

    # Returns all selected columns for the currently managed generated query
    # Format: [Column1, Column2, Column3]
    #--------------------------------------------------------------
    def used_columns
      @used_columns ||= get_columns.map {|c| QueryColumn.new(self, c)}
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

    # Converts the query to a ruby string
    #--------------------------------------------------------------
    def to_s(options = {})
      options.reverse_merge!({:joins => true, :order => true})

      result = ""

      if main_model
        query = build_query
        result = %{#{main_model}.find(:all, #{query.pretty_inspect})}
      end

      result
    end

    # Generates the necessary javascript options for the DataTables plugin
    #--------------------------------------------------------------
    def table_js
      result = {}
      result["aaSorting"] = []
      output_columns.each_index do |index|
        uc = output_columns[index]
        next unless uc.order
        result["aaSorting"] << [index, uc.order]
      end

      result
    end

    # Checks if there is at least one condition which requires a
    # variable to be set.
    #--------------------------------------------------------------
    def conditions_with_variables?
      used_columns.each do |qc|
        qc.conditions.each do |condition|
          return true if condition.type == "variable"
        end
      end
      false
    end

    def get_used_column(model, column)
      column_name = column.is_a?(String) ? column : column.name
      used_columns.detect {|uc| uc.model_name == model.name && uc.column_name == column_name}
    end

    # Returns the query attributes as Hash
    #--------------------------------------------------------------
    def to_hash
      result = {}
      #Make sure, the currently serialized values are up to date
      self.columns = used_columns.sort{|x,y| x.position <=> y.position}.map(&:to_hash)

      #Put necessary attributes in a hash
      ["name", "main_model", "models", "associations", "model_offsets", "columns"].each do |attribute|
        result[attribute] = self.send("get_#{attribute}")
      end
      result
    end

    # Adds the given model to the model list unless it's already included
    # Returns +true+ if the model was added
    #--------------------------------------------------------------
    def add_model(model)
      unless models.include?(model.to_s)
        models << model.to_s
        return true
      end
      false
    end

    # Removes the given model from the currently managed GeneratedQuery
    # Also removes all associations from and to it
    # All deleted models will be returned.
    #--------------------------------------------------------------
    def remove_model(model)
      #Return if the model to be deleted is the main model
      return [] if model.to_s == main_model.to_s

      models.delete(model.to_s)
      removed_models = [model]

      #Remove all associations with this model as source
      remove_association_chain(model.to_s)

      #Remove all associations with this model as target
      associations.each do |source_name, association_targets|
        association_targets.each do |association_name, target_name|
          if target_name == model.to_s
            remove_association(source_name, association_name)
          end
        end
      end

      #Remove all columns from this model
      removed_model_strings = removed_models.map &:to_s
      used_columns.delete_if {|qc| qc.model_name == model.to_s}

      #remove offsets saved for this model
      model_offsets.delete(model.to_s)

      removed_models
    end

    # Adds an association to the currently managed GeneratedQuery
    # Parameter:
    #   source      -- The model which is the association's start point
    #   association -- The association name which is set up in source
    # If the end point of the association is not yet in the models,
    # it will be added automatically.
    # Returns true if the model was automatically added
    #
    # Associations are saved in the following format in the session:
    # {"source" => {:association1 => "Target1", :association2 => "Target2"}
    #
    # The associations could be saved as simple array, but in some
    # cases it makes sense to have easy access to the target without
    # having to re-search it.
    #--------------------------------------------------------------
    def add_association(source, association, target)
      add_model(source)
      result = add_model(target)

      associations[source.to_s] ||= {}
      associations[source.to_s][association.to_s] = target.to_s

      result
    end

    # Removes all associations from the given model
    #--------------------------------------------------------------
    def remove_association_chain(model)
      associations_for(model).each do |association_name, target|
        remove_association_chain(target)
      end
      self.associations[model.to_s] = {}
    end

    # Removes the given association from the currently managed
    # GeneratedQuery
    # If an association is deleted, all associations with it as
    # root have to be deleted as well as we are using the ActiveRecord
    # join generator.
    #--------------------------------------------------------------
    def remove_association(source, association)
      target = associations[source.to_s][association.to_s]
      remove_association_chain(target)
      self.associations[source.to_s].delete(association.to_s)
    end

    def uses_column?(model, column)
      !get_used_column(model, column).nil?
    end

    # Toggles if the given column is used in this query
    #--------------------------------------------------------------
    def toggle_column(model, column)
      column_name = column.is_a?(String) ? column : column.name
      uses_column?(model, column_name) ? remove_column(model, column_name) : add_column(:model => model, :column_name => column_name)
    end

    # Adds the column to the query
    #--------------------------------------------------------------
    def add_column(options = {})
      options.merge!({:position => get_columns.size})
      used_columns << QueryColumn.new(options)
      self.columns = used_columns.sort{|x,y| x.position <=> y.position}.map(&:to_hash)
    end

    # Removes the column from the query. Also checks if the column
    # is used in a condition and deletes these as well.
    #--------------------------------------------------------------
    def remove_column(model, column)
      qc = get_used_column(model, column)

      #check for conditions with the current column and delete them
      used_columns.each do |uc|
        uc.conditions.delete_if {|condition| condition.type == "column" && condition.value == qc.full_column_name}
      end

      used_columns.delete(qc)
      self.columns = used_columns.sort{|x,y| x.position <=> y.position}.map(&:to_hash)
    end

    private

    # Generates the ":order => """ part of the query
    #--------------------------------------------------------------
    def order_by
      order = []
      used_columns.each do |qc|
        order << qc.order_by_string if qc.order
      end
      order.join(", ")
    end
    
    # Generates the ":group => ..." part
    #--------------------------------------------------------------
    def group_by
      result = []
      used_columns.each do |qc|
        result << qc.full_column_name if qc.group_by
      end
      result
    end

    # Generates the ":conditions => " part of the query
    # Only valid conditions are used.
    #--------------------------------------------------------------
    def build_conditions(variables = {})
      condition_names = []
      condition_values = []
      used_columns.each do |qc|
        current_level = 1
        qc.conditions.each do |condition|
          if condition.type == "variable"
            variable_value = variables[qc.full_column_name][qc.conditions.index(condition)] rescue nil
            condition.set_variable(variable_value)
          end

          next unless condition.valid?
          condition_options = {}
          condition_options[:connector] = condition_names.any?
          condition_options[:opening_bracket] = condition.level > current_level
          condition_options[:initial_closing_bracket] = condition.level < current_level
          condition_options[:closing_bracket] =  condition.level > 1 && condition == qc.conditions.last

          condition_text = condition.to_s(condition_options)

          current_level = condition.level
          condition_names << condition_text
          condition_values << condition.value if condition.type == "value"
        end
      end
      condition_names.any? ? ([condition_names.join(" ")] + condition_values) : []
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

    # Tests if this is the end of an association chain
    #--------------------------------------------------------------
    def is_end_association?(model, association)
      target = model_associations[model][association]
      model_associations[target].nil?
    end
  end
end