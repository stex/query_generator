window.queryGenerator =
  data:
    token:
      key: null,
      value: null

  urls:
    updateOffset: null
    fetchQueryRecords: null
    updateProgressView: null

  pageElements:
    recordPreview: "#model-records-preview"
    conditionDialog: "#model-column-conditions"

  init: () ->
    jQuery(this.pageElements.recordPreview).dialog(autoOpen: false, modal: true, width: "90%", height: "700")
    jQuery(this.pageElements.conditionDialog).dialog(autoOpen: false, resizable: false, modal: true, width: "auto", height: "400",
      buttons:
        Ok: () ->
          jQuery( this ).dialog( "close" )
    )
    @helpers.createAjaxIndicator()

  # Used to display a model's records in a jQuery UI dialog
  #--------------------------------------------------------------
  displayModelRecords: (dialogTitle, content) ->
    jQuery(this.pageElements.recordPreview).html(content)
    jQuery(this.pageElements.recordPreview).dialog("option", {title: dialogTitle})
    jQuery(this.pageElements.recordPreview).dialog("open")

  # Displays the dialog to edit column conditions
  #--------------------------------------------------------------
  editColumnConditions: (dialogTitle, content) ->
    jQuery(this.pageElements.conditionDialog).html(content)
    jQuery(this.pageElements.conditionDialog).dialog("option", {title: dialogTitle})
    jQuery(this.pageElements.conditionDialog).dialog("open")

  createOutputTable: (element, options) ->
    defaults = {
      "bJQueryUI": true,
      "sPaginationType": "full_numbers",
      "iDisplayLength": 50,
      "bProcessing": true,
      "bServerSide": true,
      "bFilter": false,
      "sAjaxSource": queryGenerator.urls.fetchQueryRecords,
      "fnServerData": (sSource, aoData, fnCallback) ->
        jQuery.getJSON sSource, aoData, (json) ->
          jQuery('#flash').html(json.flashMessages)
          jQuery('html, body').animate({scrollTop:0}, 'fast');
          #pass the data to the standard callback and draw the table
          fnCallback(json)
    }

    settings = jQuery.extend({}, defaults, options)
    jQuery(element).dataTable(settings)

  # Updates the way the wizard progress should be shown
  #--------------------------------------------------------------
  setProgressView: (progressView, remote) ->
    jQuery(".progress > .progress-view").hide()
    jQuery(".progress > .#{progressView}").show()

    remote = true unless remote?

    if remote == true
      ajaxData = {
        progress_view: progressView
      }

      if (queryGenerator.data.token.key != null)
        ajaxData[queryGenerator.data.token.key] = queryGenerator.data.token.value;

      jQuery.ajax
        url: queryGenerator.urls.updateProgressView,
        data: ajaxData,
        type: "post"


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
        stop: @updateModelBoxOffsets)

    createDraggables: (selectorCommand) ->
      @createDraggable(jQuery(selectorCommand))

    # Returns the serialized model box offsets for the given draggable element
    #--------------------------------------------------------------
    getModelBoxOffset: (ui) ->
      #jQuery.param {
      {
        offset: [ui.offset.top, ui.offset.left],
        model: ui.helper.attr("id").replace("model_", "")
      }
      #}

    setModelBoxOffset: (id, _top, _left) ->
      jQuery("##{id}").offset
        top: _top,
        left: _left

    updateModelBoxOffsets: (event, ui) ->
      ajaxData = queryGenerator.graph.getModelBoxOffset(ui)
      if (queryGenerator.data.token.key != null)
        ajaxData[queryGenerator.data.token.key] = queryGenerator.data.token.value;

      jQuery.ajax
        url: queryGenerator.urls.updateOffset,
        data: ajaxData,
        type: "post"

      
    # Expects a hash {id => [offsetTop, offsetLeft}
    #--------------------------------------------------------------
    setModelBoxOffsets: (offsets) ->
      jQuery.each offsets, (key, value) =>
        @setModelBoxOffset(key, value[0], value[1])
      
    # expects connections in the format [[elem1, elem2, label]]
    #--------------------------------------------------------------
    addConnections: (connections) ->
      for connection in connections
        @addConnection(connection[0], connection[1], connection[2])
                                 
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