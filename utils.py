import itertools
import networkx as nx
import math

import networkx as nx
import matplotlib.pyplot as plt
import copy
import networkx as nx

'''def remove_edges_for_display(g):
    remove_edge = []
    checked_edges = set()
    for s, t in g.edges():
        if (t, s) not in checked_edges:
            checked_edges.add((s, t))
        else:
            remove_edge.append((s, t))
    g.remove_edges_from(remove_edge)'''

def filter_edges_nodes(g, query_nodes, tf_ranks, rangeSlider_co_exp):
    '''
    list of integers
    '''
    to_remove_e1 = []
    to_remove_n1 = set()  # Set to hold nodes to be removed

    if len(tf_ranks) == 0:
        pass
    else:
        
        for s, t, k, d in g.edges(keys=True, data=True):  
            if k == 'directed':  
                if d['tf_rank'] not in tf_ranks:
                    to_remove_e1.append((s, t, k))
            else:
                if 0 not in tf_ranks:
                    to_remove_e1.append((s, t, k))

        g.remove_edges_from(set(to_remove_e1))
        

        for node in g.nodes():
            # Skip query nodes
            if node in query_nodes:
                continue
            
            # Check if there is a path to any query node
            is_connected = any(nx.has_path(g, query_node, node) for query_node in query_nodes)
            if not is_connected:
                to_remove_n1.add(node)
        g.remove_nodes_from(to_remove_n1)
    


    #range Slider
    to_remove_e = []
    for s, t, k, d in g.edges(keys=True, data=True):
        if k != 'directed':
            if d["irp_score"] < rangeSlider_co_exp:
                to_remove_e.append((s, t, k))
    g.remove_edges_from(set(to_remove_e))

    to_remove_n = set()  # Set to hold nodes to be removed

    for node in g.nodes():
        # Skip query nodes
        if node in query_nodes:
            continue
        
        # Check if there is a path to any query node
        is_connected = any(nx.has_path(g, query_node, node) for query_node in query_nodes)
        if not is_connected:
            to_remove_n.add(node)
    g.remove_nodes_from(to_remove_n)
    print('...')
    print('nodes removed', to_remove_n1, 'edges removed', to_remove_e1)
    print('nodes removed', to_remove_n, 'edges removed', to_remove_e)
    print('...')




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






def expand_nodes(g, nodes, all_shown_nodes, tf_ranks, slideRange_co_exp):
    if len(nodes) > 1:
        print('Error : expand not implemented for more than one node')
    node = nodes[0]
    ug = nx.MultiGraph(g.copy())

    # Find neighbors of the selected node(s)
    all_neighbours = set(nodes)
    fromnodes = nodes
    for i in range(1):
        neighbours = set(itertools.chain.from_iterable([g.neighbors(n) for n in fromnodes]))
        if not neighbours:
            break
        all_neighbours.update(neighbours)
        fromnodes = neighbours

    # Filter the subgraph based on tf_ranks and slideRange_co_exp using filter_edges_nodes
    filtered_subgraph = g.copy()
    filter_edges_nodes(filtered_subgraph, query_nodes=[node], tf_ranks=tf_ranks, rangeSlider_co_exp=slideRange_co_exp)
    potentialEdges = []
    print('all_neighbours', all_neighbours)
    print('all_shown_nodes',all_shown_nodes)
    print('nodes',nodes)
    # Find potential edges after filtering
    for fr, to in [(a, b) for a in set(all_neighbours) - set(nodes) for b in set(all_shown_nodes) - set(nodes)]:
        print('considering: ', fr, to)
        '''if g.has_edge(fr, to):
            edges = g.get_edge_data(fr, to)
            for k, attrs in edges.items():
                potentialEdges.append((fr, to, k, attrs))
        elif g.has_edge(to, fr):
            edges = g.get_edge_data(to, fr)
            for k, attrs in edges.items():
                potentialEdges.append((to, fr, k, attrs))'''
            
        if filtered_subgraph.has_edge(fr, to):
            edges = filtered_subgraph.get_edge_data(fr, to)
            for k, attrs in edges.items():
                potentialEdges.append((fr, to, k, attrs))
        elif filtered_subgraph.has_edge(to, fr):
            edges = filtered_subgraph.get_edge_data(to, fr)
            for k, attrs in edges.items():
                potentialEdges.append((to, fr, k, attrs))

    # Return the subgraph and potential edges
    #print('-----')
    #print('filterednodes',filtered_subgraph.nodes())
    #print('filterededges',filtered_subgraph.edges())
    #print('-----')      
    return g.subgraph([node] + list(filtered_subgraph.neighbors(node))), potentialEdges






def graph2json(g, query_nodes=[]):
    groups_json = {'CKN node': {'shape': 'box',
                              'color': {'background': 'white'}}}
    nlist = []
    for nodeid, attrs in g.nodes(data=True):
        nodeData = copy.deepcopy(attrs)
        nodeData['id'] = nodeid
        nodeData['label'] = nodeid
        
        if nodeData['isTF'] == 1: #in case isTF
            nodeData['color'] = {'border': '#afaba2',
                                 'background': '#f5be15'}
            nodeData['shape'] = 'box'
        
        elif nodeData['isTR'] == 1: #in case isTR
            nodeData['color'] = {'border': '#afaba2',
                                 'background': '#79e34e'}
            nodeData['shape'] = 'box'
        
        for key, value in nodeData.items():
            if isinstance(value, float) and math.isnan(value):
                nodeData[key] = None  # Use None instead of null for JSON serialization

        if nodeid in query_nodes:
            nodeData['color'] = {'border': "#e3530b",
                                 'background': '#f09d62'
                                } 
            nodeData['borderWidth'] = 2
        nlist.append(nodeData)

    elist = []
    #dict tf_rank : edge width
    tf_width_dict = {
    0: 6,
    1: 8,
    2: 10,
    3: 12
    }
    
    
            
    for fr, to, attrs in g.edges(data=True):      
        elist.append({
                    'from': attrs.get('source', fr),
                    'to': attrs.get('target', to),
                    'id': attrs.get('id', ''),
                    'label': attrs.get('interaction', ''),
                    'interaction': attrs.get('interaction', ''),
                    'irp_score': attrs.get('irp_score', 0),
                    'ConnecTF_Target': attrs.get('ConnecTF_Target', ''),
                    'cis_elements': attrs.get('cis_elements', 0),
                    'tf_rank': attrs.get('tf_rank', 0),  
                    'width': attrs.get('width', 1),  
                    'directed': attrs.get('directed', 'no'),
                    'arrows': attrs.get('arrows', 'undefined'),
                    'hidden': attrs.get('hidden', False)
                })
    

        
    result =  {'network': {'nodes': nlist, 'edges': elist}, 'groups': groups_json}
    return result












