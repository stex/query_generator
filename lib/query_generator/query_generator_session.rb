# Session helper for creating / editing generated queries

module QueryGenerator
  class QueryGeneratorSession

    def initialize(session)
      @session = session
    end

    def init_for_generated_query(generated_query)
      @session[:query_generator] = nil
    end

    def add_model(model)
      session_namespace[:models] ||= []
      session_namespace[:models] << model.to_s
    end

    def models
      session_namespace[:models] ||= []
      session_namespace[:models].map {|m| m.constantize }
    end

    private

    def session_namespace
      @session[:query_generator] ||= {}
      @session[:query_generator]
    end

  end
end