(function() {

  window.queryGenerator = {
    data: {
      token: {
        key: null,
        value: null
      }
    },
    urls: {
      updateOffset: null,
      fetchQueryRecords: null,
      updateProgressView: null
    },
    pageElements: {
      recordPreview: "#model-records-preview",
      conditionDialog: "#model-column-conditions"
    },
    init: function() {
      jQuery(this.pageElements.recordPreview).dialog({
        autoOpen: false,
        modal: true,
        width: "90%",
        height: "700"
      });
      jQuery(this.pageElements.conditionDialog).dialog({
        autoOpen: false,
        modal: true,
        width: "auto",
        height: "400"
      }, {
        buttons: {
          Ok: function() {
            return jQuery(this).dialog("close");
          }
        }
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
    editColumnConditions: function(dialogTitle, content) {
      jQuery(this.pageElements.conditionDialog).html(content);
      jQuery(this.pageElements.conditionDialog).dialog("option", {
        title: dialogTitle
      });
      return jQuery(this.pageElements.conditionDialog).dialog("open");
    },
    createOutputTable: function(element, options) {
      var defaults, settings;
      defaults = {
        "bJQueryUI": true,
        "sPaginationType": "full_numbers",
        "iDisplayLength": 50,
        "bProcessing": true,
        "bServerSide": true,
        "bFilter": false,
        "sAjaxSource": queryGenerator.urls.fetchQueryRecords,
        "fnServerData": function(sSource, aoData, fnCallback) {
          return jQuery.getJSON(sSource, aoData, function(json) {
            jQuery('#flash').html(json.flashMessages);
            jQuery('html, body').animate({
              scrollTop: 0
            }, 'fast');
            return fnCallback(json);
          });
        }
      };
      settings = jQuery.extend({}, defaults, options);
      return jQuery(element).dataTable(settings);
    },
    setProgressView: function(progressView, remote) {
      var ajaxData;
      jQuery(".progress > .progress-view").hide();
      jQuery(".progress > ." + progressView).show();
      if (remote == null) {
        remote = true;
      }
      if (remote === true) {
        ajaxData = {
          progress_view: progressView
        };
        if (queryGenerator.data.token.key !== null) {
          ajaxData[queryGenerator.data.token.key] = queryGenerator.data.token.value;
        }
        return jQuery.ajax({
          url: queryGenerator.urls.updateProgressView,
          data: ajaxData,
          type: "post"
        });
      }
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
        return jQuery("#" + node).remove();
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
