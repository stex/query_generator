(function() {

  window.queryGenerator = {
    nodes: null,
    edges: null,
    pageElements: {
      recordPreview: "#model-records-preview",
      wizard: "#query-generator"
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
          containerHeight: "100%",
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
          mainModel: false
        };
        options = jQuery.extend({}, defaults, options);
        newElem = jQuery(document.createElement(options.type)).addClass("block draggable model").addClass(options.mainModel && "main-model").attr("id", id).html(content);
        jQuery(this.canvasSelector).append(newElem);
        return jsPlumb.draggable(newElem, {
          containment: queryGenerator.graph.canvasSelector,
          scroll: false,
          handle: ".handle"
        });
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
        jsPlumb.detachAll(node);
        return jQuery("#" + node).remove();
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
