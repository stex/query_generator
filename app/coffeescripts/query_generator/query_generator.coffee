window.queryGenerator =
  data:
    nodes: {}
    edges: {}

  pageElements:
    recordPreview: "#model-records-preview"
    wizard: "#wizard"

  urls:
    values: "/generated_queries/set_values"

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
    # Creates the horizontal accordion which is used for the wizard
    #--------------------------------------------------------------
    init: ->
      jQuery(queryGenerator.pageElements.wizard).liteAccordion(
        containerHeight: "95%",
        containerWidth: "100%",
        contentPadding: 10,
        linkable: true,
        enumerateSlides: true).liteAccordion("disableSlide", 1).liteAccordion("disableSlide", 2)

    # Shortcut to disable a wizard slide
    #--------------------------------------------------------------
    disableSlide: (nameOrIndex) -> jQuery(queryGenerator.pageElements.wizard).liteAccordion("disableSlide", nameOrIndex)

    # Shortcut to enable a wizard slide
    #--------------------------------------------------------------
    enableSlide: (nameOrIndex) -> jQuery(queryGenerator.pageElements.wizard).liteAccordion("enableSlide", nameOrIndex)

    # Shortcut to open the given wizard slide
    #--------------------------------------------------------------
    openSlide: (nameOrIndex) -> jQuery(queryGenerator.pageElements.wizard).liteAccordion("openSlide", nameOrIndex)

    # Sets the current wizard step and disables all other slides
    #--------------------------------------------------------------
    setStep: (index) ->
      @disableSlide(i) for i in [0..2]
      @enableSlide(index)
      @openSlide(index)

    # Generates the model offsets for the third step
    # in the format {dom_id => [offsetTop, offsetLeft]}
    #--------------------------------------------------------------
    getModelBoxOffsets: ->
      positions = {}

      jQuery.each queryGenerator.data.nodes, (key, value) =>
        positions[key] = [value.offset().top, value.offset().left]

      jQuery.param {offsets: positions}

  graph:
    canvasSelector: "#graph"
    init: ->
      null

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

      #Place the main model in the center of the graph canvas
      if (options.mainModel == true)
        newElem.css("left", (jQuery(@canvasSelector).width() / 2) - (newElem.width() / 2))
        newElem.css("top", (jQuery(@canvasSelector).height() / 2) - (newElem.height() / 2))

      jsPlumb.draggable(newElem, { containment: queryGenerator.graph.canvasSelector, scroll: false, handle: ".handle" })

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
        jsPlumb.repaint(value);

    # Removes all nodes from the current graph
    #--------------------------------------------------------------
    removeAllNodes: () ->
      jQuery.each queryGenerator.data.nodes, (key, value) =>
        jsPlumb.detachAllConnections(value)
        jQuery(value).remove()
      queryGenerator.data.nodes = {}



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