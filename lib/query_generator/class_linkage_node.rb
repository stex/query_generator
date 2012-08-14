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
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    # Initializes a new node
    # Parameters:
    #  klass: The class this node belongs to
    #  edges: If edges already exist for some reason, they can be attached directly.
    #--------------------------------------------------------------
    def initialize(klass, edges = HashWithIndifferentAccess.new)
      @klass = klass.to_s
      @edges = edges
      @shortest_paths = HashWithIndifferentAccess.new
    end

    # Returns the class this node is attached to
    #--------------------------------------------------------------
    def klass
      @klass.constantize
    end

    # Returns all edges for this node in the format
    # {"ModelName" => {association_name_1 => options_1, association_name_2 => options_2}}
    # This is necessary as one model might be connected to the same
    # model multiple times (e.g. created_by / updated_by, etc)
    #--------------------------------------------------------------
    def edges
      @edges
    end

    # Returns the node edges in the format
    # {"association_name" => Model, ...}
    #--------------------------------------------------------------
    def connected_model_associations
      return @connected_model_associations if @connected_model_associations

      @connected_model_associations = HashWithIndifferentAccess.new
      @edges.each do |end_point, associations|
        model = end_point.constantize
        associations.keys.each do |association|
          @connected_model_associations[association.to_s] = model
        end
      end
      @connected_model_associations
    end

    # Returns the model which is the given association's end point
    #--------------------------------------------------------------
    def get_model_by_association(association_name)
      connected_model_associations[association_name.to_s]
    end

    # Returns all models which are directly connected to this node
    #--------------------------------------------------------------
    def connected_models
      @connected_models ||= @edges.keys.map {|k| k.constantize }
    end

    # Shortcut to get the graph this node is in
    #--------------------------------------------------------------
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
    #  {"ModelName" => {association_name_1 => options_1, association_name_2 => options_2}}
    #--------------------------------------------------------------
    def is_connected_to!(end_point, options)
      @edges[end_point.to_s] ||= HashWithIndifferentAccess.new
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

       if current_model.to_s == model.to_s
         @shortest_paths[current_model] = path_to[current_model]
       end

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