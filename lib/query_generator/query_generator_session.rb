# Session helper for creating / editing generated queries

module QueryGenerator

  class QueryGeneratorSession
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    def initialize(session)
      @session = session
    end

    def init_for_generated_query(generated_query)
      @session[:query_generator] = nil
    end

    # Adds the given model to the associations list
    #--------------------------------------------------------------
    def add_model(model)
      session_namespace[:models] ||= []
      if model != self.main_model && !session_namespace[:models].include?(model.to_s)
        session_namespace[:models] << model.to_s
      end
      @models = nil
    end

    def models
      session_namespace[:models] ||= []
      @models ||= session_namespace[:models].map {|m| m.constantize }
    end

    # The main model for the generated query
    #--------------------------------------------------------------
    def main_model
      @main_model ||= session_namespace[:main_model].try(:constantize)
    end

    # Sets the main model for the generated query
    #--------------------------------------------------------------
    def main_model=(model)
      session_namespace[:main_model] = model.to_s
      @main_model = model
    end


    # Returns all associations for the currently managed GeneratedQuery
    # Format:
    # {source => [associations]}
    #--------------------------------------------------------------
    def associations
      return @associations if @associations
      @associations = {}

      session_namespace[:associations].each do |source, associations|
        @associations[source.constantize] = associations
      end
      @associations
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
    # {"source" => [association1, association2, ...], ...}
    #--------------------------------------------------------------
    def add_association(source, association)
      result = false

      end_point = DataHolder.instance.linkage_graph.get_node(source).get_model_by_association(association)

      unless models.include?(end_point)
        add_model(end_point)
        result = true
      end

      session_namespace[:associations] ||= {}
      session_namespace[:associations][source.to_s] ||= []
      session_namespace[:associations][source.to_s] << association

      @associations = nil

      result
    end


    private

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

  end
end