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
    urls: {
      values: "/generated_queries/set_values"
    },
    init: function() {
      jQuery(this.pageElements.recordPreview).dialog({
        autoOpen: false,
        modal: true,
        width: "90%",
        height: "700"
      });
      return queryGenerator.wizard.init();
    },
    displayModelRecords: function(dialogTitle, content) {
      jQuery(this.pageElements.recordPreview).html(content);
      jQuery(this.pageElements.recordPreview).dialog("option", {
        title: dialogTitle
      });
      return jQuery(this.pageElements.recordPreview).dialog("open");
    },
    wizard: {
      init: function() {
        return jQuery(queryGenerator.pageElements.wizard).liteAccordion({
          containerHeight: "95%",
          containerWidth: "100%",
          contentPadding: 10,
          linkable: true,
          enumerateSlides: true
        }).liteAccordion("disableSlide", 1).liteAccordion("disableSlide", 2);
      },
      disableSlide: function(nameOrIndex) {
        return jQuery(queryGenerator.pageElements.wizard).liteAccordion("disableSlide", nameOrIndex);
      },
      enableSlide: function(nameOrIndex) {
        return jQuery(queryGenerator.pageElements.wizard).liteAccordion("enableSlide", nameOrIndex);
      },
      openSlide: function(nameOrIndex) {
        return jQuery(queryGenerator.pageElements.wizard).liteAccordion("openSlide", nameOrIndex);
      },
      setStep: function(index) {
        var i, _i;
        for (i = _i = 0; _i <= 2; i = ++_i) {
          this.disableSlide(i);
        }
        this.enableSlide(index);
        return this.openSlide(index);
      },
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
      init: function() {
        return null;
      },
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
        if (options.mainModel === true) {
          newElem.css("left", (jQuery(this.canvasSelector).width() / 2) - (newElem.width() / 2));
          newElem.css("top", (jQuery(this.canvasSelector).height() / 2) - (newElem.height() / 2));
        }
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
      }
    }
  };

}).call(this);
