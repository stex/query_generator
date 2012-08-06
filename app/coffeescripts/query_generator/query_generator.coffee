window.queryGenerator =
  nodes: null
  edges: null

  pageElements:
    recordPreview: "#model-records-preview"
    wizard: "#query-generator"

  init: () ->
    jQuery(this.pageElements.recordPreview).dialog(autoOpen: false, modal: true, width: "90%", height: "700")
    queryGenerator.wizard.init()

  # Used to display a model's records in a jQuery UI dialog
  #--------------------------------------------------------------
  displayModelRecords: (dialogTitle, content) ->
    jQuery(this.pageElements.recordPreview).html(content)
    jQuery(this.pageElements.recordPreview).dialog("option", {title: dialogTitle})
    jQuery(this.pageElements.recordPreview).dialog("open")

  wizard:
    init: ->
      jQuery(queryGenerator.pageElements.wizard).liteAccordion(
        containerHeight: "95%",
        containerWidth: "99%",
        rounded: true, linkable: true).find("slide-content:first").show()

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
  *                 Callbacks                   *
  ***********************************************
  ###


  ###
  ***********************************************
  *              Getters / Setters              *
  ***********************************************
  ###

  setNodes: (jsonNodes) ->
    queryGenerator.nodes = jsonNodes
    queryGenerator.edges = []

    jQuery(jsonNodes).each (index, node) -> queryGenerator.edges[node.klass] = node.edges

  ###
  ***********************************************
  *              Helper Functions               *
  ***********************************************
  ###
  helpers:

    windowHeightPercent: (percent) ->
      jQuery(window).height() * (percent / 100)
    windowWidthPercent: (percent) ->
      jQuery(window).width() * (percent / 100)