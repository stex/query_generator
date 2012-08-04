(function() {

  window.queryGenerator = {
    nodes: null,
    edges: null,
    pageElements: {
      recordPreview: "#model-records-preview"
    },
    init: function() {
      return jQuery(this.pageElements.recordPreview).dialog({
        autoOpen: false,
        modal: true,
        width: "90%",
        height: "700"
      });
    },
    displayModelRecords: function(dialogTitle, content) {
      jQuery(this.pageElements.recordPreview).html(content);
      jQuery(this.pageElements.recordPreview).dialog("option", {
        title: dialogTitle
      });
      return jQuery(this.pageElements.recordPreview).dialog("open");
    },
    graph: {
      canvasSelector: "#graph",
      init: function() {
        return null;
      },
      addNode: function(id, content, type) {
        var newElem;
        if (type == null) {
          type = "div";
        }
        newElem = jQuery(document.createElement(type)).addClass("block draggable model").attr("id", id).html(content);
        jQuery(this.canvasSelector).append(newElem);
        return jsPlumb.draggable(id, {
          containment: queryGenerator.graph.canvasSelector,
          scroll: false,
          handle: ".handle"
        });
      },
      addConnection: function(model1, model2, label) {
        return jsPlumb.connect({
          source: model1,
          target: model2,
          parameters: {}
        });
      },
      removeNode: function(node) {
        return jQuery("#" + node).remove();
      }
    },
    /*
      ***********************************************
      *                 Callbacks
      ***********************************************
    */

    /*
      ***********************************************
      *              Getters / Setters
      ***********************************************
    */

    setNodes: function(jsonNodes) {
      queryGenerator.nodes = jsonNodes;
      queryGenerator.edges = [];
      return jQuery(jsonNodes).each(function(index, node) {
        return queryGenerator.edges[node.klass] = node.edges;
      });
    }
  };

}).call(this);
