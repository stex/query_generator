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
    end

    # Returns the class this node is attached to
    #--------------------------------------------------------------
    def klass
      @klass.constantize
    end

    def edges
      @edges
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
    #--------------------------------------------------------------
    def is_connected_to!(end_point, options)
      @edges[end_point.to_s] = options
    end

    #def path_to(end_point)
    #  existing_path = [@klass]
    #  return existing_path if is_connected_to? end_point
    #
    #  @edges.each do |ep, options|
    #    next_node = @graph.get_node(ep)
    #    next_path = next_node.path_to(end_point)
     #   return (existing_path + next_path) if next_path.any?
    #  end

    #  []
    #end

  end
end