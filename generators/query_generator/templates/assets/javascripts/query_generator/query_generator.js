(function() {

  window.queryGenerator = {
    data: {
      token: {
        key: null,
        value: null
      }
    },
    urls: {
      updateOffset: null
    },
    pageElements: {
      recordPreview: "#model-records-preview"
    },
    init: function() {
      jQuery(this.pageElements.recordPreview).dialog({
        autoOpen: false,
        modal: true,
        width: "90%",
        height: "700"
      });
      return this.helpers.createAjaxIndicator();
    },
    displayModelRecords: function(dialogTitle, content) {
      jQuery(this.pageElements.recordPreview).html(content);
      jQuery(this.pageElements.recordPreview).dialog("option", {
        title: dialogTitle
      });
      return jQuery(this.pageElements.recordPreview).dialog("open");
    },
    createOutputTable: function(element, options) {
      var defaults, settings;
      defaults = {
        "bJQueryUI": true,
        "sPaginationType": "full_numbers",
        "iDisplayLength": 50
      };
      settings = jQuery.extend({}, defaults, options);
      return jQuery(element).dataTable(settings);
    },
    graph: {
      canvasSelector: "#graph",
      addConnection: function(elem1, elem2, _label) {
        var options;
        options = {
          source: jQuery(elem1),
          target: jQuery(elem2),
          connector: "StateMachine",
          paintStyle: {
            lineWidth: 3,
            strokeStyle: "#056"
          },
          hoverPaintStyle: {
            strokeStyle: "#dbe300"
          },
          endpoint: "Blank",
          anchor: "Continuous",
          overlays: [
            [
              "PlainArrow", {
                location: 1,
                width: 20,
                length: 12
              }
            ], [
              "Label", {
                label: _label,
                cssClass: "label"
              }
            ]
          ]
        };
        return jsPlumb.connect(options);
      },
      removeNode: function(node) {
        jsPlumb.detachAllConnections(node);
        jQuery("#" + node).remove();
        return jQuery("" + this.canvasSelector + " > .draggable").each(function(index) {
          var offset, parentOffset;
          offset = jQuery(this).offset();
          parentOffset = jQuery(queryGenerator.graph.canvasSelector).offset();
          if (offset.top < parentOffset.top) {
            jQuery(this).offset({
              top: parentOffset.top,
              left: offset.left
            });
          }
          return jsPlumb.repaint(this);
        });
      },
      repaintConnections: function() {
        return jQuery("" + this.canvasSelector + " > .draggable").each(function(index) {
          return jsPlumb.repaint(this);
        });
      },
      createDraggable: function(id) {
        return jsPlumb.draggable(id, {
          containment: queryGenerator.graph.canvasSelector,
          scroll: false,
          handle: ".handle",
          stop: this.updateModelBoxOffsets
        });
      },
      createDraggables: function(selectorCommand) {
        return this.createDraggable(jQuery(selectorCommand));
      },
      getModelBoxOffset: function(ui) {
        return {
          offset: [ui.offset.top, ui.offset.left],
          model: ui.helper.attr("id").replace("model_", "")
        };
      },
      setModelBoxOffset: function(id, _top, _left) {
        return jQuery("#" + id).offset({
          top: _top,
          left: _left
        });
      },
      updateModelBoxOffsets: function(event, ui) {
        var ajaxData;
        ajaxData = queryGenerator.graph.getModelBoxOffset(ui);
        if (queryGenerator.data.token.key !== null) {
          ajaxData[queryGenerator.data.token.key] = queryGenerator.data.token.value;
        }
        return jQuery.ajax({
          url: queryGenerator.urls.updateOffset,
          data: ajaxData,
          type: "post"
        });
      },
      setModelBoxOffsets: function(offsets) {
        var _this = this;
        return jQuery.each(offsets, function(key, value) {
          return _this.setModelBoxOffset(key, value[0], value[1]);
        });
      },
      addConnections: function(connections) {
        var connection, _i, _len, _results;
        _results = [];
        for (_i = 0, _len = connections.length; _i < _len; _i++) {
          connection = connections[_i];
          _results.push(this.addConnection(connection[0], connection[1], connection[2]));
        }
        return _results;
      }
    },
    /*
      ***********************************************
      *                 Callbacks                   *
      ***********************************************
    */

    /*
      ***********************************************
      *              Getters / Setters              *
      ***********************************************
    */

    setNodes: function(jsonNodes) {
      queryGenerator.nodes = jsonNodes;
      queryGenerator.edges = [];
      return jQuery(jsonNodes).each(function(index, node) {
        return queryGenerator.edges[node.klass] = node.edges;
      });
    },
    /*
      ***********************************************
      *              Helper Functions               *
      ***********************************************
    */

    helpers: {
      windowHeightPercent: function(percent) {
        return jQuery(window).height() * (percent / 100);
      },
      windowWidthPercent: function(percent) {
        return jQuery(window).width() * (percent / 100);
      },
      createAjaxIndicator: function() {
        jQuery(document).ajaxStart(function() {
          return jQuery("#query-generator > .ajax-indicator").show();
        });
        return jQuery(document).ajaxStop(function() {
          return jQuery("#query-generator > .ajax-indicator").hide();
        });
      }
    }
  };

}).call(this);
