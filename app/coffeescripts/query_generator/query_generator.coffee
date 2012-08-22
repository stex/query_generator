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

    # Adds a connection between two nodes and visualizes it with
    # jsPlumb (draws a connection between the two draggable boxes)
    #--------------------------------------------------------------
    addConnection: (elem1, elem2, _label) ->
      options =
        source: jQuery(elem1)
        target: jQuery(elem2)
        connector:"StateMachine"
        paintStyle:{lineWidth:3,strokeStyle:"#056"}
        hoverPaintStyle:{strokeStyle:"#dbe300"}
        endpoint:"Blank"
        anchor:"Continuous"
        overlays: [ ["PlainArrow", {location:1, width:20, length:12}], ["Label", {label: _label, cssClass: "label"}]]

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

      #Sometimes elements get moved around, so we have to make sure, everything's still inside of the container
      jQuery("#{@canvasSelector} > .draggable").each (index) ->
        offset = jQuery(@).offset()
        parentOffset = jQuery(queryGenerator.graph.canvasSelector).offset()
        if offset.top < parentOffset.top
          jQuery(@).offset({top: parentOffset.top, left: offset.left})
        jsPlumb.repaint(@)


    # Repaints all connections in the graph.
    # This is necessary when the boxes were manipulated through
    # js
    #--------------------------------------------------------------
    repaintConnections: () ->
      jQuery("#{@canvasSelector} > .draggable").each (index) ->
        jsPlumb.repaint(@)

    createDraggable: (id) ->
      jsPlumb.draggable(id,
        containment: queryGenerator.graph.canvasSelector,
        scroll: false, handle: ".handle",
        stop: queryGenerator.callbacks.dragStop)

    createDraggables: (selectorCommand) ->
      @createDraggable(jQuery(selectorCommand))

    # Returns the serialized model box offsets for the given draggable element
    #--------------------------------------------------------------
    getModelBoxOffset: (ui) ->
      jQuery.param {
        offset: [ui.offset.top, ui.offset.left],
        model: ui.helper.attr("id").replace("model_", "")
      }

    setModelBoxOffset: (id, _top, _left) ->
      jQuery("##{id}").offset
        top: _top,
        left: _left


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