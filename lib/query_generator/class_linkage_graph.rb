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



  end
end