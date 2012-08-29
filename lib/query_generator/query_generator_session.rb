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

    def unfinished_query?
      !@session[:query_generator].nil?
    end

    def current_step
      @current_step ||= session_namespace[:current_step] || 1
    end

    def current_step=(step)
      session_namespace[:current_step] = @current_step = step.to_i
    end

    def query
      generated_query
    end

    # Determines how the progress should be displayed
    # Possible values are:
    #  "single_line"
    #  "multi_line"
    #  "sql"
    #--------------------------------------------------------------
    def progress_view
      @progress_view ||= session_namespace[:progress_view] || "multi_line"
    end

    def progress_view=(progress_view)
      session_namespace[:progress_view] = progress_view.to_s
      @progress_view = progress_view.to_s
    end


    # Removes everything from the session
    #--------------------------------------------------------------
    def reset!
      @session.delete(:query_generator)
    end

    def generated_query
      return @generated_query if @generated_query
      @generated_query = GeneratedQuery.find(session_namespace[:generated_query_id]) rescue nil
      @generated_query ||= GeneratedQuery.new
      update_query_object
      @generated_query
    end

    # Sets the generated query to be edited through this session
    # if the query already exists, all data from it will be loaded into
    # the session.
    #--------------------------------------------------------------
    def generated_query=(generated_query)
      @generated_query = generated_query
      query_to_session
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
      update_query_object(:main_model)
      @main_model = model
    end


    # Returns all associations for the currently managed GeneratedQuery
    # Format:
    # {SourceModel => {:association => TargetModel}}
    #--------------------------------------------------------------
    def model_associations
      @model_associations ||= generated_query.model_associations
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
      result = false

      unless models.include?(target)
        add_model(target)
        result = true
      end

      session_namespace[:associations][source.to_s] ||= {}
      session_namespace[:associations][source.to_s][association.to_s] = target.to_s

      update_query_object(:associations)

      @model_associations = nil

      result
    end

    # Removes the given association from the currently managed
    # GeneratedQuery
    #--------------------------------------------------------------
    def remove_association(source, association)
      session_namespace[:associations][source.to_s].delete(association.to_s)
      update_query_object(:associations)
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
        parameters << ":include => #{joins.inspect}" if options[:joins] && joins.any?
        parameters << %{:order => "#{order}"} if options[:order] && order.any?

        result = %{#{main_model}.find(#{parameters.join(", ")})}
      end

      result
    end

    # Sets the offset for the given model
    #--------------------------------------------------------------
    def set_model_offset(model, top, left)
      session_namespace[:model_offsets][model.to_s] = [top, left]
      update_query_object(:model_offsets)
    end

    # Toggles if the currently managed query includes the given column
    #--------------------------------------------------------------
    def toggle_used_column(model, column)
      column_name = column.is_a?(String) ? column : column.name
      uses_column?(model, column_name) ? remove_column(model, column_name) : add_column(:model => model, :column_name => column_name)
      update_query_object(:columns)
    end

    # Checks if the currently managed query includes the given column
    #--------------------------------------------------------------
    def uses_column?(model, column)
      !generated_query.get_used_column(model, column).nil?
    end

    # Returns all selected columns for the currently managed generated query
    # Format: [Column1, Column2, Column3]
    #--------------------------------------------------------------
    def used_columns
      generated_query.used_columns
    end

    def get_column(model, column)
      column_name = column.is_a?(String) ? column : column.name
      used_columns.detect {|qc| qc.model_name == model.to_s && qc.column_name == column_name.to_s}
    end

    def change_column_position(model, column, amount = 1)
      edit_generated_query do |query|
        qc = query.get_used_column(model, column)
        query.used_columns[qc.position + amount].position -= amount
        qc.position += amount
      end
    end

    # Block function to edit one of the used columns in the query
    #--------------------------------------------------------------
    def edit_column(model, column)
      edit_generated_query do |query|
        yield query.get_used_column(model, column)
      end
    end

    # Block function to allow edits on the generated_query object
    # Changes will automatically be saved to the session afterwards
    #--------------------------------------------------------------
    def edit_generated_query
      yield generated_query
      query_to_session
      query.reset_instance_variables
    end

    # Updates the attributes of the currently managed query
    #--------------------------------------------------------------
    def update_query_object(certain_attribute = nil)
      gc = generated_query

      #If only a certain attribute was changed, we don't have to update them all
      if certain_attribute
        gc.send("#{certain_attribute}=", session_namespace[certain_attribute])
      else
        session_namespace[:generated_query].each do |key, value|
          gc.send("#{key}=", value)
        end
      end

      gc.reset_instance_variables
    end

    private

    # Saves the currently managed Generated Query in the session
    #--------------------------------------------------------------
    def query_to_session
      session_namespace[:generated_query] = generated_query.to_hash
      session_namespace[:generated_query_id] = generated_query.id rescue nil
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
      generated_query.joins_for(model)
    end

    # Generates the ":order => """ part of a query
    #--------------------------------------------------------------
    def order_by
      generated_query.order_by
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
    end

  end
end