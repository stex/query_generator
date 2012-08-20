(function() {

  window.queryGenerator = {
    data: {
      nodes: {},
      edges: {}
    },
    pageElements: {
      recordPreview: "#model-records-preview",
      wizard: "#wizard"
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
    wizard: {
      getModelBoxOffsets: function() {
        var positions,
          _this = this;
        positions = {};
        jQuery.each(queryGenerator.data.nodes, function(key, value) {
          return positions[key] = [value.offset().top, value.offset().left];
        });
        return jQuery.param({
          offsets: positions
        });
      }
    },
    graph: {
      canvasSelector: "#graph",
      addNode: function(id, content, options) {
        var defaults, newElem;
        defaults = {
          type: "div",
          mainModel: false,
          placeNearSelector: ".main-model"
        };
        options = jQuery.extend({}, defaults, options);
        newElem = jQuery(document.createElement(options.type)).addClass("block draggable model").addClass(options.mainModel && "main-model").attr("id", id).html(content);
        jQuery(this.canvasSelector).append(newElem);
        jsPlumb.draggable(newElem, {
          containment: queryGenerator.graph.canvasSelector,
          scroll: false,
          handle: ".handle"
        });
        return queryGenerator.data.nodes[id] = newElem;
      },
      addConnection: function(elem1, elem2, options) {
        var defaults;
        defaults = {
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
            ]
          ]
        };
        options = jQuery.extend({}, defaults, options);
        return jsPlumb.connect(options);
      },
      removeNode: function(node) {
        var _this = this;
        jsPlumb.detachAllConnections(node);
        jQuery("#" + node).remove();
        delete queryGenerator.data.nodes[node];
        return jQuery.each(queryGenerator.data.nodes, function(key, value) {
          var offset, parentOffset;
          offset = jQuery(value).offset();
          parentOffset = jQuery(_this.canvasSelector).offset();
          if (offset.top < parentOffset.top) {
            jQuery(value).offset({
              top: parentOffset.top,
              left: offset.left
            });
          }
          return jsPlumb.repaint(value);
        });
      },
      removeAllNodes: function() {
        var _this = this;
        jQuery.each(queryGenerator.data.nodes, function(key, value) {
          jsPlumb.detachAllConnections(value);
          return jQuery(value).remove();
        });
        return queryGenerator.data.nodes = {};
      },
      repaintConnections: function() {
        var _this = this;
        return jQuery.each(queryGenerator.data.nodes, function(key, value) {
          return jsPlumb.repaint(value);
        });
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
