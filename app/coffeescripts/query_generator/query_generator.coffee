window.queryGenerator =
  data:
    nodes: {}
    edges: {}

  callbacks: {
    dragStop: (event, ui) ->
      alert(ui)
  }

  pageElements:
    recordPreview: "#model-records-preview"

  init: () ->
    jQuery(this.pageElements.recordPreview).dialog(autoOpen: false, modal: true, width: "90%", height: "700")
    @helpers.createAjaxIndicator()

  # Used to display a model's records in a jQuery UI dialog
  #--------------------------------------------------------------
  displayModelRecords: (dialogTitle, content) ->
    jQuery(this.pageElements.recordPreview).html(content)
    jQuery(this.pageElements.recordPreview).dialog("option", {title: dialogTitle})
    jQuery(this.pageElements.recordPreview).dialog("open")

  graph:
    canvasSelector: "#graph"

    # Adds a node to the current graph. This will create
    # a new draggable box inside the graph area
    #--------------------------------------------------------------
    addNode: (id, content, options) ->
      defaults =
        type: "div"
        mainModel: false
        placeNearSelector: ".main-model"

      options = jQuery.extend({}, defaults, options)

      newElem = jQuery(document.createElement(options.type))
        .addClass("block draggable model")
        .addClass(options.mainModel && "main-model")
        .attr("id", id)
        .html(content)

      jQuery(@canvasSelector).append(newElem);

      jsPlumb.draggable(newElem,
        containment: queryGenerator.graph.canvasSelector,
        scroll: false, handle: ".handle",
        stop: queryGenerator.callbacks.dragStop)

      queryGenerator.data.nodes[id] = newElem

    # Adds a connection between two nodes and visualizes it with
    # jsPlumb (draws a connection between the two draggable boxes)
    #--------------------------------------------------------------
    addConnection: (elem1, elem2, options) ->
      defaults =
        source: jQuery(elem1)
        target: jQuery(elem2)
        connector:"StateMachine"
        paintStyle:{lineWidth:3,strokeStyle:"#056"}
        hoverPaintStyle:{strokeStyle:"#dbe300"}
        endpoint:"Blank"
        anchor:"Continuous"
        overlays: [ ["PlainArrow", {location:1, width:20, length:12} ]]

      options = jQuery.extend({}, defaults, options)

      jsPlumb.connect(options)

#      queryGenerator.data.edges[elem1] = [] unless queryGenerator.data.edges[elem1]?
#      queryGenerator.data.edges[elem1].push jQuery(elem2)

    # Removes the given node
    #--------------------------------------------------------------
    removeNode: (node) ->
      #Delete all connections from and to this
      jsPlumb.detachAllConnections(node)
      #Remove the DOM element
      jQuery("##{node}").remove()

      #Remove the node from our local node list
      delete queryGenerator.data.nodes[node]

      #Sometimes elements get moved around, so we have to make sure, everything's still inside of the container
      jQuery.each queryGenerator.data.nodes, (key, value) =>
        offset = jQuery(value).offset()
        parentOffset = jQuery(@canvasSelector).offset()
        if offset.top < parentOffset.top
          jQuery(value).offset({top: parentOffset.top, left: offset.left})
        jsPlumb.repaint(value)

    # Removes all nodes from the current graph
    #--------------------------------------------------------------
    removeAllNodes: () ->
      jQuery.each queryGenerator.data.nodes, (key, value) =>
        jsPlumb.detachAllConnections(value)
        jQuery(value).remove()
      queryGenerator.data.nodes = {}

    # Repaints all connections in the graph.
    # This is necessary when the boxes were manipulated through
    # js
    #--------------------------------------------------------------
    repaintConnections: () ->
      jQuery.each queryGenerator.data.nodes, (key, value) =>
        jsPlumb.repaint(value)

    # Returns the serialized model box offsets for the given draggable element
    #--------------------------------------------------------------
    getModelBoxOffset: (ui) ->
      jQuery.param {
        offset: [ui.offset.top, ui.offset.left],
        model: ui.helper.attr("id").replace("model_", "")
      }


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

    createAjaxIndicator: () ->
      jQuery(document).ajaxStart () ->
        jQuery("#query-generator > .ajax-indicator").show()
      jQuery(document).ajaxStop () ->
        jQuery("#query-generator > .ajax-indicator").hide()