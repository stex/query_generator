queryGenerator =
  nodes: null
  edges: null

  graph:
    canvasSelector: "#graph"

    init: ->
      null

    addNode: (id, content, type) ->
      type = "div" unless type?

      newElem = jQuery(document.createElement(type))
        .addClass("block draggable model")
        .attr("id", id)
        .html(content)

      jQuery(this.canvasSelector).append(newElem);

      jsPlumb.draggable(id, { containment: queryGenerator.graph.canvasSelector, scroll: false, handle: ".handle" })

    ###
    * Adds a connection between two nodes
    * @param model1
    * @param model2
    * @param label
    ###
    addConnection: (model1, model2, label) ->
      myConnection = jsPlumb.connect({
        source: model1,
        target: model2,
        parameters:{}
      })

    removeNode: (node) ->
      jQuery("#" + node).remove()


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