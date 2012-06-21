=begin
  Edges in this graph are one-way.
  Although usually associations between models are in a fix schema,
  e.g. has_many <=> belongs_to, this cannot be guaranteed throughout
  all possible applications.

 Edges are saved in a hash-format with the endpoint model as
 key and options as value (e.g. association name).
 This makes finding an association as easy as possible.
=end

module QueryGenerator
  class ClassLinkageNode

    # Initializes a new node
    # Parameters:
    #  klass: The class this node belongs to
    #  edges: If edges already exist for some reason, they can be attached directly.
    #--------------------------------------------------------------
    def initialize(klass, edges = {})
      @klass = klass.to_s
      @edges = edges
      @shortest_paths = HashWithIndifferentAccess.new
    end

    # Returns the class this node is attached to
    #--------------------------------------------------------------
    def klass
      @klass.constantize
    end

    def edges
      @edges
    end

    # Returns all models which are directly connected to this node
    #--------------------------------------------------------------
    def connected_models
      @edges.keys.map {|k| k.constantize }
    end

    def graph
      QueryGenerator::DataHolder.instance.linkage_graph
    end

    # Checks if this node is directly connected to another node
    # Parameters:
    #   end_point: A class name or class
    #--------------------------------------------------------------
    def is_connected_to?(end_point)
      @edges.keys.include?(end_point.to_s)
    end

    # Sets up an edge between this node and another one
    # The end point here is not the other node, but the class the
    # node is attached to. This allows simple graph manipulation without
    # having to change pointers.
    # Parameters:
    #  end_point:        Class or class name of the other model
    #  options:          Various association options coming from ActiveRecord.
    #
    # The edges are stored in the following format:
    #  {ModelName => {association_name_1 => options_1, association_name_2 => options_2}}
    #--------------------------------------------------------------
    def is_connected_to!(end_point, options)
      @edges[end_point.to_s] ||= {}
      @edges[end_point.to_s][options[:name]] = options
    end

    # Performs a Breadth First Search on the linkage graph
    # to find a path to the given model.
    # It will return the shortest one it finds.
    #--------------------------------------------------------------
    def get_shortest_path_to(model)
      visited_models = []
      model_queue = Queue.new

      path_to = HashWithIndifferentAccess.new

      model_queue << @klass
      visited_models << @klass

      path_to[@klass] = []

      until model_queue.empty?
       current_model = model_queue.pop
       current_node = graph.get_node(current_model)

       return @shortest_paths[current_model] = path_to[current_model] if current_model.to_s == model.to_s

       current_node.edges.each do |end_point, associations|
         unless visited_models.include?(end_point)
           path_to[end_point] = path_to[current_model] + [end_point]
           model_queue << end_point
           visited_models << end_point
         end
       end
      end

      []
    end

  end
end