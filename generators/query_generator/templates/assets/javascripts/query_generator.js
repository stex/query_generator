var queryGenerator = {

    nodes: null,
    edges: null,

    setupLinkageWheel: function(canvas) {
        var wheelData = new Array();

        jQuery(queryGenerator.nodes).each(function (index, node) {
            var nodeEdges = new Array();

            jQuery.each(queryGenerator.edges[node.klass], function(endPoint, options) {
                nodeEdges.push(endPoint);
            });

            wheelData.push({id: node.klass, text: node.klass, connections: nodeEdges});
        });

        var wheel = new MooWheel(wheelData, $moo(canvas), {radialMultiplier: 10});
    },

    graph: {
        canvasSelector: "#graph",

        init: function() {

        },

        addNode: function(id, content, type) {
            if (type == null)
                type = "div";

            var newElem = jQuery(document.createElement(type))
                .addClass("block draggable model")
                .attr("id", id)
                .html(content);

            jQuery(this.canvasSelector).append(newElem);

            jsPlumb.draggable(id, { containment: queryGenerator.graph.canvasSelector, scroll: false, handle: ".handle" });
        },

        /**
         * Adds a connection between two nodes
         * @param model1
         * @param model2
         * @param label
         */
        addConnection: function(model1, model2, label) {
            var myConnection = jsPlumb.connect({
                source: model1,
                target: model2,
                parameters:{}
            });
        },

        removeNode: function(node) {
            jQuery("#" + node).remove();
        }
    },

    /***********************************************
     *                 Callbacks
     ***********************************************/


    /***********************************************
     *              Getters / Setters
     ***********************************************/

    setNodes: function(jsonNodes) {
        queryGenerator.nodes = jsonNodes;

        queryGenerator.edges = new Object();

        jQuery(jsonNodes).each(function (index, node) {
            queryGenerator.edges[node.klass] = node.edges;
        });

    }

};