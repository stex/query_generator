# Session helper for creating / editing generated queries

# Session Namespaces:
#
#   :models           -- ["model1", "model2", ...]
#   :associations     -- {"source" => {:association1 => "Target1", :association2 => "Target2"}
#   :main_model       -- "Main Model used for query"
#   :model_offsets    -- {"model" => [top, left]}
#   :columns          -- [{column_1_options}, {column_2_options}, ...]
#   :query_attributes -- Some core attributes for the generated_query, e.g. :name

module QueryGenerator

  class QueryGeneratorSession
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    def initialize(session)
      @session = session
    end

    def current_step
      @current_step ||= session_namespace[:current_step] || 1
    end

    def current_step=(step)
      session_namespace[:current_step] = @current_step = step.to_i
    end

    def generated_query
      return @generated_query if @generated_query
      @generated_query = GeneratedQuery.find(session_namespace[:generated_query_id]) rescue nil
      @generated_query ||= GeneratedQuery.new
    end

    # Removes everything from the session
    #--------------------------------------------------------------
    def reset!
      @session.delete(:query_generator)
    end

    # Sets the generated query to be edited through this session
    # if the query already exists, all data from it will be loaded into
    # the session.
    #--------------------------------------------------------------
    def generated_query=(generated_query)
      if generated_query.new_record?
        create_namespaces(true)
        session_namespace[:generated_query_id] = nil
      else
        create_namespaces
        session_namespace[:generated_query_id] = generated_query.id
        [:main_model, :models, :associations, :model_offsets, :columns].each do |attribute|
          session_namespace[attribute] = generated_query.send(attribute)
        end

        session_namespace[:query_attributes] = {:name => generated_query.name}
      end

      @generated_query = generated_query
    end

    # Updates attributes like name
    #--------------------------------------------------------------
    def update_query_attributes(attributes = {})
      session_namespace[:query_attributes] = attributes
    end

    # Updates the query record and tries to save it
    #--------------------------------------------------------------
    def save_generated_query
      update_query_object
      generated_query.save
    end

    # Adds the given model to the associations list
    #--------------------------------------------------------------
    def add_model(model)
      if model != self.main_model && !session_namespace[:models].include?(model.to_s)
        session_namespace[:models] << model.to_s
      end
      @models = nil
    end

    # Removes the given model from the currently managed GeneratedQuery
    # Also removes all associations from and to it
    # If other models are connected with this model as source, they
    # are removed as well as they have no more connection to the graph
    #--------------------------------------------------------------
    def remove_model(model)
      session_namespace[:models].delete(model.to_s)

      removed_models = [model]

      #Remove all associations with this model as source
      associations_with_source(model).each do |association, target|
        remove_association(model, association)
        removed_models += remove_model(target)
      end

      #Remove all associations with this model as target
      associations_with_target(model).each do |source, associations|
        associations.each do |association|
          remove_association(source, association)
        end
      end

      #remove offsets saved for this model
      session_namespace[:model_offsets].delete(model.to_s)

      @models = nil

      removed_models
    end

    # Checks if the currently managed GeneratedQuery somehow uses
    # the given model, either in the models or as main_model
    #--------------------------------------------------------------
    def uses_model?(model)
      model = model.constantize unless model.is_a?(Class)
      main_model == model || models.include?(model)
    end

    def models
      @models ||= session_namespace[:models].map {|m| m.constantize }
    end

    # Returns all models incl. the main model
    #--------------------------------------------------------------
    def used_models
      [main_model] + models
    end

    # The main model for the generated query
    #--------------------------------------------------------------
    def main_model
      @main_model ||= session_namespace[:main_model].try(:constantize)
    end

    # Sets the main model for the generated query
    # If the main model is different from the previous one,
    # most namespaces will be reset.
    #--------------------------------------------------------------
    def main_model=(model)
      #Check if there was an old main_model set. If yes and the new one is different,
      #delete the chosen associations and values
      if session_namespace[:main_model] != model.to_s
        create_namespaces(true)
      end

      session_namespace[:main_model] = model.to_s
      @main_model = model
    end


    # Returns all associations for the currently managed GeneratedQuery
    # Format:
    # {SourceModel => {:association => TargetModel}}
    #--------------------------------------------------------------
    def model_associations
      return @model_associations if @model_associations
      @model_associations = {}

      #Test if there is at least one registered association
      if has_value?(:associations)
        session_namespace[:associations].each do |source, associations|
          source_model = source.constantize
          associations.each do |association, target|
            @model_associations[source_model] ||= HashWithIndifferentAccess.new
            @model_associations[source_model][association] = target.constantize
          end
        end
      end
      @model_associations
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
    def add_association(source, association)
      result = false

      target = DataHolder.instance.linkage_graph.get_node(source).get_model_by_association(association)

      unless models.include?(target)
        add_model(target)
        result = true
      end

      session_namespace[:associations][source.to_s] ||= {}
      session_namespace[:associations][source.to_s][association.to_s] = target.to_s

      @model_associations = nil

      result
    end

    # Removes the given association from the currently managed
    # GeneratedQuery
    #--------------------------------------------------------------
    def remove_association(source, association)
      session_namespace[:associations][source.to_s].delete(association.to_s)
      @model_associations = nil
    end

    # Generates a preview string for the currently managed
    # GeneratedQuery
    #--------------------------------------------------------------
    def preview_string(options = {})
      options.reverse_merge!({:joins => false})

      result = ""

      if main_model
        joins = joins_for(main_model)
        order = order_by

        parameters = [":all"]
        parameters << ":joins => #{joins.inspect}" if options[:joins] && joins.any?
        parameters << %{:order => "#{order}"} if options[:order] && order.any?

        result = %{#{main_model}.find(#{parameters.join(", ")})}
      end

      result
    end

    # Returns the saved model offsets for the given model
    #--------------------------------------------------------------
    def model_offsets(model)
      session_namespace[:model_offsets][model.to_s]
    end

    # Sets the offset for the given model
    #--------------------------------------------------------------
    def set_model_offset(model, top, left)
      session_namespace[:model_offsets][model.to_s] = [top, left]
    end

    # Toggles if the currently managed query includes the given column
    #--------------------------------------------------------------
    def toggle_used_column(model, column)
      column_name = column.is_a?(String) ? column : column.name
      uses_column?(model, column_name) ? remove_column(model, column_name) : add_column(:model => model, :column_name => column_name)
    end

    # Checks if the currently managed query includes the given column
    #--------------------------------------------------------------
    def uses_column?(model, column)
      column_name = column.is_a?(String) ? column : column.name
      !(session_namespace[:columns].detect {|c| c["model"] == model.to_s && c["column_name"] == column_name.to_s}).nil?
    end

    # Returns all selected columns for the currently managed generated query
    # Format: [Column1, Column2, Column3]
    #--------------------------------------------------------------
    def used_columns
      @used_columns ||= session_namespace[:columns].map {|c| QueryColumn.new(c)}
    end

    def change_column_position(model, column, amount = 1)
      column_options = get_column_from_namespace(model, column)
      next_column = get_column_by_position(column_options["position"] + amount)
      column_options["position"] += amount
      next_column["position"] -= amount
      session_namespace[:columns].sort! {|x,y| x["position"] <=> y["position"]}
      @used_columns = nil
    end

    def update_column_options(model, column, options = {})
      col = get_column_from_namespace(model, column)
      qc = used_columns[col["position"]]
      qc.update_options(options)
      session_namespace[:columns][col["position"]] = qc.serialized_options
    end

    private

    # Makes sure the necessary namespaces are set in the session
    #--------------------------------------------------------------
    def create_namespaces(force = false)
      if force
        session_namespace[:models] = []
        session_namespace[:associations] = {}
        session_namespace[:model_offsets] = {}
        session_namespace[:columns] = []
        session_namespace[:query_attributes] = {}
      else
        session_namespace[:models] ||= []
        session_namespace[:associations] ||= {}
        session_namespace[:model_offsets] ||= {}
        session_namespace[:columns] ||= []
        session_namespace[:query_attributes] ||= {}
      end
    end

    def get_column_from_namespace(model, column)
      column_name = column.is_a?(String) ? column : column.name
      session_namespace[:columns].detect {|c| c["model"] == model.to_s && c["column_name"] == column_name.to_s}
    end

    def get_column_by_position(position)
      session_namespace[:columns].detect {|c| c["position"] == position.to_i}
    end

    def add_column(options = {})
      options.merge!({:position => session_namespace[:columns].size})
      new_column = QueryColumn.new(options)
      session_namespace[:columns] << new_column.serialized_options
      @used_columns = nil
    end

    def remove_column(model, column)
      session_namespace[:columns].delete_if {|c| c["model"] == model.to_s && c["column_name"] == column.to_s}
      @used_columns = nil
    end

    # Recursive function to build the joins array based on
    # the used associations.
    # If a model only has one association, the array around
    # them will be removed for better readability
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

    # Generates the ":order => """ part of a query
    #--------------------------------------------------------------
    def order_by
      order = []
      used_columns.each do |qc|
        order << qc.order_by_string if qc.order
      end
      order.join(", ")
    end

    # Tests if this is the end of an association chain
    #--------------------------------------------------------------
    def is_end_association?(model, association)
      target = model_associations[model][association]
      model_associations[target].nil?
    end

    # Returns all associations which have the given model as source
    # format: {:association1 => Target1}
    #--------------------------------------------------------------
    def associations_with_source(model)
      model = model.constantize unless model.is_a?(Class)
      model_associations[model] || []
    end
    # Returns all associations which have the given model as Target
    # Format: {SourceModel => [:association1, :association2, ...], ...}
    # as we already have the target
    #--------------------------------------------------------------
    def associations_with_target(model)
      model = model.constantize unless model.is_a?(Class)
      target_associations = {}

      model_associations.each do |source, associations|
        associations.each do |association, target|
          if target == model
            target_associations[source] ||= []
            target_associations[source] << association
          end
        end
      end

      target_associations
    end

    # Checks if the given namespace was already registered under the
    # session namespace
    #--------------------------------------------------------------
    def has_value?(namespace)
      !session_namespace[namespace].blank?
    end

    def session_namespace
      @session[:query_generator] ||= {}
      @session[:query_generator]
    end

    # Updates the attributes of the currently managed query
    #--------------------------------------------------------------
    def update_query_object
      gc = generated_query

      session_namespace[:query_attributes].each do |key, value|
        gc.send("#{key}=", value)
      end

      [:main_model, :models, :associations, :model_offsets, :columns].each do |attribute|
        gc.send("#{attribute}=", session_namespace[attribute])
      end

      gc
    end

  end
end