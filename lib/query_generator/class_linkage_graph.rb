module QueryGenerator

  class ClassLinkageGraph
    def initialize
      @nodes = {}
    end

    # Returns the node for the given class
    #--------------------------------------------------------------
    def get_node(klass)
      @nodes[klass.to_s]
    end

    def nodes
      @nodes.values
    end

    # Adds a node for the given class to the graph
    #--------------------------------------------------------------
    def add_node(klass)
      @nodes[klass.to_s] = QueryGenerator::ClassLinkageNode.new(klass)
    end

    # Searches for an existing node for the given class first.
    # If it cannot be found, it creates a new node.
    #--------------------------------------------------------------
    def get_or_add_node(klass)
      get_node(klass) || add_node(klass)
    end

    def get_shortest_path_to(model1, model2)
      visited_models = []
      model_queue = Queue.new

      path_to = HashWithIndifferentAccess.new

      model_queue << model1.to_s
      visited_models << model1.to_s

      path_to[model1.to_s] = [model1.to_s]

      until model_queue.empty?
        current_model = model_queue.pop
        current_node = get_node(current_model)

        if current_model.to_s == model2.to_s
          get_node(model1).add_path(current_model, path_to[current_model])
        else
          current_node.edges.each do |end_point, options|
            unless visited_models.include?(end_point)
              path_to[end_point] = path_to[current_model] + [end_point]
              puts "adding #{end_point}"
              model_queue << end_point
              visited_models << end_point
            end
          end
        end

      end
      get_node(model1).get_paths_to(model2)
    end



  end
end