// prevents dialog closing immediately when page navigates
vex.defaultOptions.closeAllOnPopState = false;

var netviz = {
    nodes: undefined,
    edges: undefined,
    network: undefined,
    isFrozen: false,
    newNodes: undefined,
    newEdges: undefined
};


// var network = null;
var node_search_data = null;
var node_search_data_dict = null;
var select = null;
var selectedRanks = new Set();
var rangeSliderValue = 0

var validNodes = []

//format.extend (String.prototype, {});

$(window).resize(function() {
    scale();
});

function enableSpinner() {
    // disable button
    $('#searchButton').prop("disabled", true);
    // add spinner to button
    $('#searchButton').html(`<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> searching...`);
}

function disableSpinner() {
    // enable button
    $('#searchButton').prop("disabled", false);
    // add back text only
    $('#searchButton').html('search');
}

// ajax request once the html is loaded to get node info
$(document).ready(function() {
    // Fetch node data from the server
    
    $.ajax({
        url: "/get_node_data",
        dataType: 'json',
        type: "POST",
        contentType: 'application/json; charset=utf-8',
        processData: false,

        success: function(data, textStatus, jQxhr) {
            node_search_data = data.node_data;
            node_search_data_dict = Object.assign({}, ...node_search_data.map((x) => ({[x.id]: x})));
            console.log("Node data loaded:", node_search_data_dict);
        },
        error: function(jqXhr, textStatus, errorThrown) {
            //console.error("Error:", textStatus, errorThrown);  // Log the error details
            alert('Server error while loading node data.');
        }
    });
    $('#dropdownMenu a').click(function(){
        if ($(this).attr('href') == '#nodes') {
            export_nodes();
        }
        else if ($(this).attr('href') == '#edges') {
            export_edges();
        } else if ($(this).attr('href') == '#png') {
            export_network_png();
        } else if ($(this).attr('href') == '#report') {
            generate_report();
        }
    });
    


    // Event listener for the search button
    $('#searchButton').click(function(event) {
        event.preventDefault();  // Prevent the default form submission and page reload
        console.log('ranks', selectedRanks)
        const userInput = $('input[name="query"]').val().trim();
        const queryNodes = userInput.split(/\s+/);  // Split by space
        validNodes = queryNodes.filter(node => node in node_search_data_dict);  // Check valid nodes
        const invalidNodes = queryNodes.filter(node => !(node in node_search_data_dict));  // Check invalid nodes

        
        // If no valid nodes, show an error message
        if (validNodes.length === 0) {
            alert('None of the input nodes correspond to valid Cork Oak names.');
            return;
        }
    
        // If invalid nodes exist, show a warning
        if (invalidNodes.length > 0) {
            alert(`The following elements are not valid: ${invalidNodes.join(', ')}`);
        }
        console.log('valid nodes',validNodes),
        enableSpinner();  // Show loading spinner
        
        // Make AJAX POST request
        $.ajax({
          url: "/search",
          dataType: 'json',
          type: "POST",
          contentType: 'application/json; charset=utf-8',
          processData: false,
          data: JSON.stringify({'nodes': Array.from(validNodes),
                                'ranks': Array.from(selectedRanks),  // Convert Set to Array before sending
                                'rangeSliderValue': parseFloat(rangeSliderValue)

          }),
          success: function( data, textStatus, jQxhr ){
              netviz.isFrozen = false;
              drawNetwork(data);  // Visualize the network with the data returned
              disableSpinner();  // Hide loading spinner
          },
          error: function(jqXhr, textStatus, errorThrown) {
              disableSpinner();  // Hide loading spinner
              alert('Server error while loading the network.');
          },

    
    
    });
    


    scale();
    initContextMenus();

    
    
    
});


function drawNetwork(graphData){
    console.log("Graph Data Received:", graphData);
    console.log('edge data before viz', graphData.network.edges);

    netviz.nodes = new vis.DataSet(graphData.network.nodes);
    netviz.edges = new vis.DataSet(graphData.network.edges);
    // create a network
    var container = document.getElementById('networkView');

        // provide the data in the vis format
    var data = {
        nodes: netviz.nodes,
        edges: netviz.edges
    };
    console.log("netviz.nodes:", netviz.nodes);
    console.log('netviz data', data)
    //https://visjs.github.io/vis-network/docs/network/#options
    
    var options = {groups: graphData.groups,
                    interaction: {
                        navigationButtons: true,
                        keyboard: true,
                        hover: true,
                        multiselect:true,
                        
                    },
                    edges: {
                        //arrows: 'to',
                        smooth: {
                            enabled: true,
                            type: 'dynamic',
                            forceDirection: 'none'
                        },
                        font: {
                            size: 12,
                            face: 'sans',
                            align: 'top',
                            color: '#332f2f',
                        },
                        chosen: {
                            label: hover_edge_label
                        },
                        color: {color: '#6d468f', hover: '#513cd6', highlight: '#513cd6'},
                        hoverWidth: 2.2,
                        width: 2
                        },
                    nodes: {
                        shape: 'circle',
                        color: '#c7bba9',
                        widthConstraint: { maximum: 100},
                        font: {
                            multi: 'html'
                        },
                        chosen: {
                            node: hover_node,
                            label: hover_node_label
                        }
                    },
                    physics: {
                        enabled: true,
                        solver: 'barnesHut',
                        barnesHut: {
                            gravitationalConstant: -18000,
                            centralGravity: 0.01,
                            springLength: 200,
                            springConstant: 0.16,
                            damping:  netviz.nodes.length > 100 ? 0.5 : 0.2,
                        },
                        repulsion: {
                            centralGravity: 0,
                            springLength: 150,
                            springConstant: 0.05,
                            nodeDistance: 170,
                            damping: 0.1
                        },
                        stabilization: {
                                enabled: true,
                                iterations: netviz.nodes.length > 100 ? 50: 100,
                                fit: true
                                // updateInterval: 5,
                            },
                    },
                    configure: {
                        enabled: false
                    },
                    layout :{
                        improvedLayout: true
                    }   
    };
    postprocess_edges(data.edges);
    postprocess_nodes(data.nodes);
    console.log('edge items',data.edges)

    netviz.network = new vis.Network(container, data, options);
    netviz.network.on('dragStart', onDragStart);
    netviz.network.on('dragEnd', onDragEnd);
    netviz.network.setOptions({interaction:{tooltipDelay:3600000}}); //disable info table to appear when hovered
    netviz.network.on("stabilizationIterationsDone", function (params) {
        disableSpinner();
    });

    }
}); 

function hover_edge_label(values, id, selected, hovering) {
  values.mod = 'normal';
}

function hover_node_label(values, id, selected, hovering) {
  values.mod = 'normal';
}

function hover_node(values, id, selected, hovering) {
  values.borderWidth = 2.2;
  values.borderColor = '#513cd6'
  // values.color = 'blue'
}




function postprocess_edge(item) {

    let maxlen = 100;
    let header = '<table class="table table-striped table-bordered tooltip_table"><tbody>';
    let footer = '</tbody></table>';

    let data = [];
    if (item.directed == 'yes') {
        data = [
            ['id', item.id],
            ['ConnecTF_Target', item.ConnecTF_Target],
            ['cis_elements', item.cis_elements],
            ['tf_rank', item.tf_rank],
            ['directed', item.directed]
        ];
    } else {
        data = [
            ['id', item.id],
            ['irp_score', item.irp_score],
            ['directed', item.directed]
        ];
    }

    // Generate the table rows
    let table = '';
    data.forEach(function (item, index) {
        if (item[1] != null) {
            let row = '<tr>\
                            <td><strong>' + item[0] + '</strong></td>\
                            <td class="text-wrap">' + item[1] + '</td>\
                       </tr>';
            table += row;
        }
    });
    table = header + table + footer;
    item.title = htmlTitle(table);
    return item;


}


function postprocess_edges(edges) {
    edges.forEach((item, i) => {
        edges[i] = postprocess_edge(item);
    });
}

function postprocess_node(node) {
    
    let maxlen = 100;
    

    let header = '<div style="overflow-x:auto;">\
                  <table class="table table-striped table-bordered tooltip_table">\
                  <tbody>';
    let footer = '</tbody>\
                  </table>\
                  </div>';

    let data = [['ID', node.label],
                ['homolog of Arabidopsis Concise', node.Arabidopsis_concise],
                ['Eccentricity', node.Eccentricity],
                ['BetweennessCentrality', node.BetweennessCentrality],
                ['isTR', node.isTR == 'TR' ? 'True' : 'False'],
                ['isTF', node.isTF == 'TF' ? 'True' : 'False']];

    let table = '';
    data.forEach(function (pair) {
        if (pair[1] != null) {
            let row = '<tr>\
                            <td><strong>' + pair[0] + '</strong></td>\
                            <td class="text-wrap">' + pair[1] + '</td>\
                       </tr>';
            table += row;
        }
    });
    table = header + table + footer;
    node.title = htmlTitle(table);
    return node;
}

function postprocess_nodes(nodes) {
    nodes.forEach((item, i) => {
        console.log('postproceesing ' + item.label);
        nodes[i] = postprocess_node(item);
    });
}

function htmlTitle(html) {
  const container = document.createElement("div");
  container.classList.add('node_tooltip')
  container.innerHTML = html;
  return container;
}




function scale() {
    $('#networkView').height(verge.viewportH());
    $('#networkView').width($('#networkViewContainer').width());
}

function freezeNodes(state){
    // Allows, or not, to move the nodes
    netviz.network.setOptions( { physics: !state } );
}

function onDragStart(obj) {
    if (obj.hasOwnProperty('nodes') && obj.nodes.length==1) {
        var nid = obj.nodes[0];
        netviz.nodes.update({id: nid, fixed: false});
    }

}

function onDragEnd(obj) {
    if (netviz.isFrozen==false)
        return
    var nid = obj.nodes;
    if (obj.hasOwnProperty('nodes') && obj.nodes.length==1) {
        var nid = obj.nodes[0];
        netviz.nodes.update({id: nid, fixed: true});
    }
}

function formatNodeInfoVex(nid) {
    return netviz.nodes.get(nid).title;
}

function formatEdgeInfoVex(nid) {
    return netviz.edges.get(nid).title;
}

function edge_present(edges, newEdge) {
    var is_present = false;
    var BreakException = {};

    try {
        edges.forEach((oldEdge, i) => {
            if (newEdge.from == oldEdge.from &&
                newEdge.to == oldEdge.to &&
                newEdge.label == oldEdge.label) {
                    is_present = true;
                    throw BreakException; // break is not available in forEach
                }
        })
    } catch (e) {
        if (e !== BreakException) throw e;
    }
    return is_present;
}

function expandNode(nid) {
    $.ajax({
      url: "/expand",
      async: false,
      dataType: 'json',
      type: "POST",
      contentType: 'application/json; charset=utf-8',
      processData: false,
      data: JSON.stringify({'nodes': [nid], 
                            'all_nodes': netviz.nodes.getIds(),
                            'ranks': Array.from(selectedRanks),  // Convert Set to Array before sending
                            'rangeSliderValue': parseFloat(rangeSliderValue)
                        }),
      success: function( data, textStatus, jQxhr ){
        console.log('expandnode data sent to app',data)
        if (data.error) {
            vex.dialog.alert('Server error when expanding the node.')
        }
        else {
            let newCounter = 0
            console.log('data.network.nodes',data.network.nodes)
            console.log('netviz.nodes',netviz.nodes)

            data.network.nodes.forEach((item, i) => {
                if (!netviz.nodes.get(item.id)) {
                    //netviz.nodes.add(postprocess_node(item));
                    postprocess_node(item);
                    netviz.nodes.add(item);
                    newCounter += 1;
                }
                else {
                    // console.log('Already present ' + item.id + item.label)
                }
            })

            data.network.edges.forEach((newEdge, i) => {
                if(!edge_present(netviz.edges, newEdge)) {
                    postprocess_edge(newEdge);
                    netviz.edges.add(newEdge);
                    newCounter += 1;
                }
            })

            data.network.potential_edges.forEach((edge, i) => {
                if(!edge_present(netviz.edges, edge)) {
                    netviz.edges.add(edge);
                    newCounter += 1;
                }
            })

            if (newCounter==0) {
                vex.dialog.alert('No nodes or edges can be added.');
            }
        }
    },
    error: function( jqXhr, textStatus, errorThrown ){
        alert('Server error while loading node data.');
    }
  });

}

function initContextMenus() {
    var canvasMenu = {
        "stop": {name: "Stop simulation"},
        "start" : {name: "Start simulation"}
    };
    var canvasMenu = {
        "freeze": {name: "Freeze positions"},
        // "release" : {name: "Start simulation"}
    };
    var nodeMenuFix = {
        "delete": {name: "Delete"},
        "expand": {name: "Expand"},
        "fix": {name: "Fix position"},
        "info": {name: "Info"}
    };
    var nodeMenuRelease = {
        "delete": {name: "Delete"},
        "expand": {name: "Expand"},
        "release": {name: "Release position"},
        "info": {name: "Info"}
    };
    var edgeMenu = {
        "delete": {name: "Delete"},
        "info": {name: "Info"}
    };

    $.contextMenu({
        selector: 'canvas',
        build: function($trigger, e) {
            // this callback is executed every time the menu is to be shown
            // its results are destroyed every time the menu is hidden
            // e is the original contextmenu event, containing e.pageX and e.pageY (amongst other data)

            var hoveredEdge = undefined;
            var hoveredNode = undefined;
            if (!$.isEmptyObject(netviz.network.selectionHandler.hoverObj.nodes)) {
                hoveredNode = netviz.network.selectionHandler.hoverObj.nodes[Object.keys(netviz.network.selectionHandler.hoverObj.nodes)[0]];
            }
            else {
                hoveredNode = undefined;
            }
            if (!$.isEmptyObject(netviz.network.selectionHandler.hoverObj.edges)) {
                hoveredEdge = netviz.network.selectionHandler.hoverObj.edges[Object.keys(netviz.network.selectionHandler.hoverObj.edges)[0]];
            }
            else {
                hoveredEdge = undefined;
            }

            // ignore auto-highlighted edge(s) on node hover
            if (hoveredNode != undefined && hoveredEdge != undefined)
                hoveredEdge = undefined;

            if (hoveredNode != undefined && hoveredEdge == undefined) {
                return {
                    callback: function(key, options) {
                        if (key == "delete") {
                            netviz.nodes.remove(hoveredNode);
                        }
                        else if (key == "expand") {
                            console.log(hoveredNode.id)
                            expandNode(hoveredNode.id);
                            //vex.dialog.alert("Not yet implemented.");
                        }
                        else if (key == "fix") {
                            netviz.nodes.update({id: hoveredNode.id, fixed: true});
                        }
                        else if (key == "release") {
                            netviz.nodes.update({id: hoveredNode.id, fixed: false});
                        }
                        else if (key == "info") {
                            vex.dialog.alert({unsafeMessage: formatNodeInfoVex(hoveredNode.id)});
                        }
                    },
                    items: netviz.nodes.get(hoveredNode.id).fixed ? nodeMenuRelease : nodeMenuFix
                };
            }
            else if (hoveredNode == undefined && hoveredEdge != undefined) {
                return {
                    callback: function(key, options) {
                        if (key == "delete") {
                            netviz.edges.remove(hoveredEdge);
                        }
                        else if (key == "info") {
                            vex.dialog.alert({unsafeMessage: formatEdgeInfoVex(hoveredEdge.id)});
                        }
                    },
                    items: edgeMenu
                };
            }
            else {
                if (netviz.isFrozen) {
                    canvasMenu.freeze.name = "Release positions";
                    return {
                        callback: function(key, options) {
                            if (key == "freeze") {
                                netviz.isFrozen = false;
                                freezeNodes(netviz.isFrozen);
                            }
                        },
                        items: canvasMenu
                    };
                }
                else {
                    canvasMenu.freeze.name = "Freeze positions";
                    return {
                        callback: function(key, options) {
                            if (key == "freeze") {
                                netviz.isFrozen = true;
                                freezeNodes(netviz.isFrozen);
                            }
                        },
                        items: canvasMenu
                    };
                }
            }
        }
    });

}

function toggleLegend() {
    const legend = document.getElementById('legend');
    if (legend.style.display === 'none' || legend.style.display === '') {
        legend.style.display = 'block';
    } else {
        legend.style.display = 'none';
    }
}

function format_cell(s){
    s = s.toString();
    s = s.trim();
    s = s.replace('\n', '');
    if (s[0]!='"' && s.slice(-1)!='"' && s.search(',')!=-1){
        s = '"' + s + '"';
    }
    return s;
}


// Toggle dropdown visibility
function toggleDropdown() {
    document.getElementById("dropdownContent").classList.toggle("show");
}

function toggleRank(rank) {
    if(selectedRanks.has(rank)) {
        selectedRanks.delete(rank)
    } else {
        selectedRanks.add(rank);
    }
    console.log(Array.from(selectedRanks)) //so that can be printed
}

//range slider
function updateRangeValue(value) {
    document.getElementById('rangeValue').textContent = parseFloat(value).toFixed(3); //3 decimal digits, always
}

// Function to filter elements based on the selected IRP score
function filterByIrpScore(minIrpScore = 0) {
    console.log("Filtering edges with IRP Score >= " + minIrpScore);
    rangeSliderValue = minIrpScore
}

function export_nodes() {
    console.log("Export nodes function called."); 
    if(netviz.nodes==undefined) {
        vex.dialog.alert('No nodes to export! You need to do a search first.');
        return;
    }

    var data = [['Arabidopsis_concise_gene', 'Arabidopsis_gene', 'AverageShortestPathLength', 'BetweennessCentrality', 'ClosenessCentrality', 'Degree', 'Eccentricity', 'Flow', 'isDEG', 'IsSingleNode', 'isTF', 'isTR', 'name', 'NeighborhoodConnectivity', 'NumberOfDirectedEdges', 'NumberOfUndirectedEdges', 'Radiality', 'SelfLoops', 'Stress', 'TopologicalCoefficient']];
    netviz.nodes.forEach(function(node, id){
        var line = new Array;

        ['Arabidopsis_concise_gene', 'Arabidopsis_gene', 'AverageShortestPathLength', 'BetweennessCentrality', 'ClosenessCentrality', 'Degree', 'Eccentricity', 'Flow', 'isDEG', 'IsSingleNode', 'isTF', 'isTR', 'name', 'NeighborhoodConnectivity', 'NumberOfDirectedEdges', 'NumberOfUndirectedEdges', 'Radiality', 'SelfLoops', 'Stress', 'TopologicalCoefficient'].forEach(function(aname){
            let atr = node[aname];
            if (atr != undefined)
                line.push(format_cell(atr));
            else
                line.push('');
        })
        data.push(line);
    })

    var datalines = new Array;
    data.forEach(function(line_elements){
        datalines.push(line_elements.join(','));
    })
    var csv = datalines.join('\n')

    var blob = new Blob([csv], {type: "text/csv;charset=utf-8"});
    saveAs(blob, "nodes.csv");
}


function export_edges(){
    console.log("Export edges function called."); 
    if(netviz.edges==undefined) {
        vex.dialog.alert('No edges to export! You need to do a search first.');
        return;
    }

    var data = [['source','target','ConnecTF_Target','EdgeBetweenness','interaction','irp_score','cis_elements']];
    netviz.edges.forEach(function(edge, id){
        var line = new Array;

        ['source','target','ConnecTF_Target','EdgeBetweenness','interaction','irp_score','cis_elements'].forEach(function(aname){
            let atr = edge[aname];
            if (atr != undefined)
                line.push(format_cell(atr));
            else
                line.push('');
        })

        data.push(line);
    })

    var datalines = new Array;
    data.forEach(function(line_elements){
        datalines.push(line_elements.join(','));
    })
    var csv = datalines.join('\n');

    var blob = new Blob([csv], {type: "text/csv;charset=utf-8"});
    saveAs(blob, "edges.csv");
}

function export_network_png() {
    
    if (!netviz || !netviz.network) {
        vex.dialog.alert('No network to export! You need to do a search first.');
        return;
    }
    netviz.network.fit();
    // Give some time for the zoom effect to complete before capturing the canvas
    setTimeout(function() {
        // Get the canvas element inside the div with class 'vis_network'
        
        var canvas = document.querySelector('.vis-network canvas');
        
        if (canvas) {
            // Convert the canvas to a data URL (base64 encoded PNG)
            var dataURL = canvas.toDataURL("image/png");

            // Create a temporary link element to download the PNG
            var link = document.createElement('a');
            link.href = dataURL;
            link.download = 'network.png';  // Filename of the exported PNG
            document.body.appendChild(link); // Append link to the body
            link.click(); // Trigger download
            document.body.removeChild(link); // Remove the link after download
        } else {
            vex.dialog.alert('No network canvas found!');
            return;
        }
    }, 500);
}

function generate_report(){
    if(netviz.edges==undefined || netviz.nodes==undefined) {
        vex.dialog.alert('No data to create a report yet! You need to do a search first.');
        return;
    }
    // Create a new dictionary to store only edge data
    const edge_data_dict = {};
    const node_data_dict = {};

    for (const key in netviz.nodes) {
        const value = netviz.nodes[key];
    
    // Check if the value is an object and contains 'from' and 'to', which are edge-specific properties
    if (value && typeof value === 'object' && value.hasOwnProperty('isTF') && value.hasOwnProperty('id')) {
        // Add the key and value to the new dictionary
        node_data_dict[key] = value;
    }
    }
    // Loop through the original dictionary
    for (const key in netviz.edges) {
        const value = netviz.edges[key];
    
    // Check if the value is an object and contains 'from' and 'to', which are edge-specific properties
    if (value && typeof value === 'object' && value.hasOwnProperty('from') && value.hasOwnProperty('to')) {
        // Add the key and value to the new dictionary
        edge_data_dict[key] = value;
    }
    }
    $.ajax({
        url: '/report',
        type: 'POST',
        contentType: 'application/json; charset=utf-8',
        dataType: '',
        data: JSON.stringify({'quried_nodes': Array.from(validNodes),
                              'tf_ranks': Array.from(selectedRanks),  // Convert Set to Array before sending
                              'rangeSliderValue': parseFloat(rangeSliderValue),
                              'nodes': node_data_dict,
                              'edges': edge_data_dict
        }),
        xhrFields: {
            responseType: 'blob' // Set the response type to blob
        },
        success: function( data, textStatus, jQxhr ){
            disableSpinner();  // Hide loading spinner
            const url = window.URL.createObjectURL(data);
            const link = document.createElement('a');
            link.href = url;

            const baseFileName = 'gene_relation_report';
            const nodeNames = validNodes.join('_'); 
            const pdfFileName = `${baseFileName}_${nodeNames}.pdf`;

            link.download = pdfFileName; // Set the dynamic file name
            document.body.appendChild(link);
            link.click();
            link.remove();
            window.URL.revokeObjectURL(url); // Clean up
        },
        error: function(jqXhr, textStatus, errorThrown) {
            disableSpinner();  // Hide loading spinner
            console.error('Error generating report:', errorThrown);
            vex.dialog.alert('Server error while generating the report.');
        }
  });

}

function navToggleDropdown() {
    const dropdownMenu = document.getElementById("dropdownMenu");
    dropdownMenu.classList.toggle("show");
}

// Close the dropdown menu if the user clicks outside of it
window.onclick = function(event) {
    if (!event.target.matches('.dropdown-toggle')) {
        const dropdowns = document.getElementsByClassName("dropdown-menu");
        for (let i = 0; i < dropdowns.length; i++) {
            const openDropdown = dropdowns[i];
            if (openDropdown.classList.contains('show')) {
                openDropdown.classList.remove('show');
            }
        }
    }
};



/*
// filter page disappers if the click is not in the button or its components
window.onclick = function(event) {
    const dropdown = document.getElementById("dropdownContent");
    const button = document.querySelector('.dropbtn');

    // Check if the click was outside the dropdown and the button
    if (!event.target.matches('.dropbtn') && !dropdown.contains(event.target)) {
        if (dropdown.classList.contains('show')) {
            dropdown.classList.remove('show'); // Hide dropdown
        }
    }
}
*/


