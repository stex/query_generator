module QueryGenerator

  class ClassLinkageGraph
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    #Holds information about the links between all models in the application (except the exluded ones)
    #
    #
    # Information storage format:
    #   @nodes = {
    #     "model_name" => {
    #       :edges => {
    #         "TargetName" => {
    #           "association_name" => {association_options}
    #         }
    #       },
    #       :associations => {
    #         "association_name" => {association_options, :target => "TargetName"}
    #       }
    #     }
    #   }

    def initialize
      @nodes = {}
    end

    # Access the node for the given Model class
    #--------------------------------------------------------------
    def [](model)
      @nodes[model.to_s]
    end

    # Adds a new node to this graph
    #--------------------------------------------------------------
    def <<(model)
      @nodes[model.to_s] = {:edges => {}, :associations => {}} unless self[model]
    end

    # Adds a new edge between source and target to the current graph
    #--------------------------------------------------------------
    def add_edge(source, target, options)
      self[source][:edges][target.to_s] ||= {}
      self[source][:edges][target.to_s][options[:name].to_s] = options
      self[source][:associations][options[:name].to_s] = options.merge({:target => target.to_s})
    end

    # Checks if there is a saved edge between the source and target model
    # This means that there is an association from source to target
    #--------------------------------------------------------------
    def has_edge?(source, target)
      self[source][:edges].keys.include?(target.to_s)
    end

    # Returns all models which are connected to the given source model
    # through associations
    #--------------------------------------------------------------
    def models_connected_to(source)
      self[source][:edges].keys.map &:constantize
    end

    # Returns all associations of the given model with the corresponding target (constantized)
    #--------------------------------------------------------------
    def associations_for(source)
      associations = {}
      self[source][:associations].each do |association_name, options|
        associations[association_name] = options[:target].constantize
      end
      associations
    end

    # Returns the associations options for the given association in source
    #--------------------------------------------------------------
    def association_options(source, association_name)
      self[source][:associations][association_name.to_s]
    end

    # Performs a Breadth First Search on the linkage graph
    # to find a path  between source and destination
    # It will return the shortest one it finds.
    #--------------------------------------------------------------
    def shortest_path_between(source, destination)
      visited_models = []
      model_queue = Queue.new

      path_to = {}

      model_queue << source.to_s
      visited_models << source.to_s

      path_to[source.to_s] = []

      until model_queue.empty?
        current_model = model_queue.pop
        current_node = self[current_model]

        if current_model.to_s == destination.to_s
          return path_to[current_model.to_s]
        end

        current_node[:edges].keys.each do |target|
          unless visited_models.include?(target)
            path_to[target] = path_to[current_model.to_s] + [target.to_s]
            model_queue << target
            visited_models << target
          end
        end
      end

      []
    end

  end
end