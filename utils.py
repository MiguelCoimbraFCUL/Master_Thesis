import itertools
import networkx as nx
import math

import networkx as nx
import matplotlib.pyplot as plt
import copy
import networkx as nx

def remove_edges_for_display(g):
    remove_edge = []
    checked_edges = set()
    for s, t in g.edges():
        if (t, s) not in checked_edges:
            checked_edges.add((s, t))
        else:
            remove_edge.append((s, t))
    g.remove_edges_from(remove_edge)



def get_autocomplete_node_data(g):
    data = []
    for name, attrs in g.nodes(data=True):
        elt = copy.deepcopy(attrs)
        elt['id'] = name
        for key, value in elt.items():
            # Check if the value is NaN and replace it with None
            if isinstance(value, float) and math.isnan(value):
                elt[key] = None  # Use None instead of null for JSON serialization
        data.append(elt)

    return {'node_data': data}

###HOP is not working correctly
def extract_neighbourhoods(ckn, nodes, k=1):
    networks = {}
    neighbours_dict = {}

    for n in nodes:
        if n in ckn.nodes():
            # Start with the current node
            all_neighbours = set()
            from_nodes = set([n])
            
            # Collect neighbours for 'k' hops
            for i in range(k):
                next_neighbours = set()
                for node in from_nodes:
                    next_neighbours.update(ckn.to_undirected().neighbors(node))

                # Update the total neighbours set and prepare for the next hop
                all_neighbours.update(next_neighbours)
                from_nodes = next_neighbours

            # Create subgraph from all collected neighbours (within 'k' hops)
            g = nx.induced_subgraph(ckn, list(all_neighbours) + [n]).copy()
            networks[n] = g
            neighbours_dict[n] = all_neighbours

            print(f"Node: {n}, Neighbours within {k} hops: {len(all_neighbours)}")

    return networks, neighbours_dict



def extract_subgraph(g, nodes, k=1):
    
    nodes = [node for node in nodes if node in g.nodes]

    all_neighbours = set(nodes)
    from_nodes = nodes
    for i in range(k):
        neighbours = set(itertools.chain.from_iterable([g.neighbors(node) for node in from_nodes]))  # - set(from_nodes)
        if not neighbours:
            break
        all_neighbours.update(neighbours)
        from_nodes = neighbours
    result = g.subgraph(all_neighbours).copy()
    return result



def extract_shortest_paths(g, query_nodes):
    if len(query_nodes) == 1:
        subgraph = extract_subgraph(g, query_nodes, k=1)
        paths_nodes = subgraph.nodes()
    else:
        paths_nodes = []
        for fr, to in itertools.combinations(query_nodes, 2):
            try:
                paths = [p for p in nx.all_shortest_paths(g, source=fr, target=to)]
                # print(paths)
                paths_nodes.extend([item for path in paths for item in path])
            except nx.NetworkXNoPath:
                print('No paths:', fr, to)
                pass
        # add back also nodes with no paths
        # this also covers the case with no paths at all
        paths_nodes = set(paths_nodes).union(query_nodes)

    return g.subgraph(paths_nodes).copy()


def expand_nodes(g, nodes, all_shown_nodes):
    if len(nodes) > 1:
        print('Error : expand not implemented for more than one node')
    node = nodes[0]
    ug = nx.Graph(g.copy())

    # find also neighbours on the second level to connect to the rest of the graph (if possible)
    all_neighbours = set(nodes)
    fromnodes = nodes
    for i in range(1):
        neighbours = set(itertools.chain.from_iterable([g.neighbors(node) for node in fromnodes]))  # - set(fromnodes)
        if not neighbours:
            break
        all_neighbours.update(neighbours)
        fromnodes = neighbours

    potentialEdges = []
    #try pairs for each combination of all_neighbours and all_shown_nodes (excluding the original nodes)
    for fr, to in [(a, b) for a in set(all_neighbours)-set(nodes) for b in set(all_shown_nodes)-set(nodes)]:
        print('considering: ', fr, to)
        if g.has_edge(fr, to):
            edges = g.get_edge_data(fr, to)
            for k in edges:
                potentialEdges.append((fr, to, edges[k]))
        elif g.has_edge(to, fr):
            edges = g.get_edge_data(to, fr)
            for k in edges:
                potentialEdges.append((to, fr, edges[k]))

    potentialEdges = g.subgraph(all_neighbours).edges(data=True)
    return g.subgraph([node] + list(ug.neighbors(node))), potentialEdges

def graph2json(g, query_nodes=[]):
    groups_json = {'CKN node': {'shape': 'box',
                              'color': {'background': 'white'}}}
    nlist = []
    for nodeid, attrs in g.nodes(data=True):
        nodeData = copy.deepcopy(attrs)
        nodeData['id'] = nodeid
        nodeData['label'] = nodeid
        for key, value in nodeData.items():
            if isinstance(value, float) and math.isnan(value):
                nodeData[key] = None  # Use None instead of null for JSON serialization

        if nodeid in query_nodes:
            nodeData['color'] = {'border': "#e3530b",
                                 'background': '#f09d62',
                                 'highlight': {'border': 'red'},  # this does not work, bug in vis.js
                                 'hover': {'border': 'red'}}  # this does not work, bug in vis.js
            nodeData['borderWidth'] = 2
        nlist.append(nodeData)

    elist = []
    
    for fr, to, attrs in g.edges(data=True):
        elist.append({'from': fr,
                      'to': to,
                      'label': attrs['interaction'],
                      'interaction': attrs['interaction'],
                      'irp_score': attrs['irp_score'],
                      'EdgeBetweenness': attrs['EdgeBetweenness'],
                      'arrows': {'to': {'enabled': True}} if attrs['interaction'] != 'interacts with' else {'to': {'enabled': False}}
                      })
    result =  {'network': {'nodes': nlist, 'edges': elist}, 'groups': groups_json}
    return result












