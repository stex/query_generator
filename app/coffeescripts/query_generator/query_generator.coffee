window.queryGenerator =
  nodes: null
  edges: null

  graph:
    canvasSelector: "#graph"

    init: ->
      null

    # Adds a node to the current graph. This will create
    # a new draggable box inside the graph area
    #--------------------------------------------------------------
    addNode: (id, content, type) ->
      type = "div" unless type?

      newElem = jQuery(document.createElement(type))
        .addClass("block draggable model")
        .attr("id", id)
        .html(content)

      jQuery(this.canvasSelector).append(newElem);

      jsPlumb.draggable(id, { containment: queryGenerator.graph.canvasSelector, scroll: false, handle: ".handle" })

    # Adds a connection between two nodes and visualizes it with
    # jsPlumb (draws a connection between the two draggable boxes)
    #--------------------------------------------------------------
    addConnection: (model1, model2, label) ->
      jsPlumb.connect({
        source: model1,
        target: model2,
        parameters: {}
      })

    removeNode: (node) -> jQuery("#" + node).remove()

  ###
  ***********************************************
  *                 Callbacks
  ***********************************************
  ###


  ###
  ***********************************************
  *              Getters / Setters
  ***********************************************
  ###

  setNodes: (jsonNodes) ->
    queryGenerator.nodes = jsonNodes
    queryGenerator.edges = []

    jQuery(jsonNodes).each (index, node) -> queryGenerator.edges[node.klass] = node.edges