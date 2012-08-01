(function() {
  var queryGenerator;

  queryGenerator = {
    nodes: null,
    edges: null,
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
      /*
          * Adds a connection between two nodes
          * @param model1
          * @param model2
          * @param label
      */

      addConnection: function(model1, model2, label) {
        var myConnection;
        return myConnection = jsPlumb.connect({
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
