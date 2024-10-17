from pathlib import Path
import gzip
import pandas as pd
import networkx as nx
import math
from load_network_utils import detect_delimiter, detect_delimiter_compressed


def ckn_to_networkx(edgesPath, nodePath):
    '''
    Requires: 1st line of edgesFile must be the header
    csv
    
    '''
    
    edgesPath = Path(edgesPath)
    nodesPath = Path(nodePath)


    #edgesFile
    edgesCompressed = False
    if not edgesPath.exists() or (edgesPath.suffix == '.gz'): #file is compressed
        edgesCompressed = True
        if edgesPath.suffix != '.gz':
            edgesPath = edgesPath.with_suffix(".csv.gz")
        
    if not edgesPath.exists():
        raise FileNotFoundError(f'The edges file was not found at {edgesPath}') 

    #nodesFile
    nodesCompressed = False
    if not nodesPath.exists() or (nodesPath.suffix == '.gz'): #file is compressed
        nodesCompressed = True
        if nodesPath.suffix != '.gz':
            nodesPath = nodesPath.with_suffix(".csv.gz")

    if not edgesPath.exists():
        raise FileNotFoundError(f'The nodes file was not found at {nodesPath}') 


    if edgesCompressed:
        openFunction = gzip.open
        delimiter = detect_delimiter_compressed(edgesPath)
        mode  = "tr"
    else:
        openFunction = open
        delimiter = detect_delimiter(edgesPath)
        mode = 'rb' 

    
    with openFunction(edgesPath, mode) as handle:
        handle.readline()
        g = nx.read_edgelist(handle,
                             delimiter = delimiter,
                             create_using = nx.MultiDiGraph(),
                             data = [
                                 ('ConnecTF_Target', str),
                                 ('EdgeBetweenness',float),
                                 ('interaction', str),
                                 ('irp_score', float),
                                 ('cis_elements', int)                       
                             ])

    if nodesCompressed:
        delimiter = detect_delimiter_compressed(nodesPath)
        node_df = pd.read_csv(nodePath, na_values = ['','null','NaN'], keep_default_na = False, sep = delimiter, compression = 'gzip')
    else:
        delimiter = detect_delimiter(nodesPath)
        node_df = pd.read_csv(nodePath, na_values = ['','null','NaN'], keep_default_na = False, sep = delimiter)
        
    
    
    
    node_df.columns = node_df.columns.str.strip() #stripping the header from spaces
    mapping = {}
    for node, attrs in g.nodes(data=True):
        nodeS = node.strip('"')
        mapping.update({node:nodeS})
        
    g = nx.relabel_nodes(g,mapping)
    print(node_df.head())  # Displays the first 5 rows by default
    node_df.set_index('name', inplace = True)

    #turn db into a dict where the keys are the names and the values are the rest of the information
    nx.set_node_attributes(g, node_df.to_dict('index'))
    
    
    directed_edges_to_add = []
    undirected_edges_to_add = []
    edges_to_remove = []
    for source, target, data in g.edges(data=True):

        #stripping interaction data
        if 'interaction' in data:
            data['interaction'] = data['interaction'].strip('"')

        data['directed'] = 'no'
        data['id'] = f'{source} interacts with {target}'
        
        #tfRank
        # no no
        if data['ConnecTF_Target'] == 'no' and data['cis_elements'] == 0:
            tf_rank = 0
        # no yes
        elif data['ConnecTF_Target'] == 'no' and data['cis_elements'] == 1:
            tf_rank = 1
        # yes no
        elif data['ConnecTF_Target'] != 'no' and data['cis_elements'] == 0:
            tf_rank = 2
        else: # yes yes
            tf_rank = 3


    
        
        #create duplicate edges
        #add the direct edges to list
        if tf_rank != 0:
            key = 'directed'
            directed_edges_to_add.append((source, target, key, dict(data), tf_rank))

        #add the direct edges to list
        else:
            key = 'undirected_copy'
            undirected_edges_to_add.append((target, source, key, dict(data)))



    #need new cicle so that im not changing the structure of the graph during the cycle above:RuntimeError: dictionary changed size during iteration
    for source, target, key, data, tf_rank in directed_edges_to_add:
        g.add_edge(source, target, key, **data)

        g[source][target][key]['directed'] = 'yes'
        g[source][target][key]['interaction'] = 'regulates expression'
        g[source][target][key]['tf_rank'] = tf_rank


        #since using undirected edges need this treatment
        #check which of the nodes is the TF. If none delete the edge
        source_is_tf = 'isTF' in g.nodes[source] and g.nodes[source]['isTF'] == 'TF'
        target_is_tf = 'isTF' in g.nodes[target] and g.nodes[target]['isTF'] == 'TF'
        if source_is_tf and not target_is_tf:
            g[source][target][key]['id'] = f'{source} modulates the expression of {target}'
            g[source][target][key]['arrows'] = {'to': {'enabled': True}}  # Arrow towards target (non-TF)
            ''' ver se faz sentido visto ser direto
            # Case 2: Target is TF, Source is not
            elif target_is_tf and not source_is_tf:
                g[target][source][key]['id'] = f'{target} modulates the expression of {source}'
                g[target][source][key]['arrows'] = {'from': {'enabled': True}}  # Arrow towards source (non-TF)
            
            # Case 3: Both Source and Target are TFs
            elif source_is_tf and target_is_tf:
                g[source][target][key]['id'] = f'{source} and {target} modulate each other'
                g[source][target][key]['arrows'] = {'to': {'enabled': True}, 'from': {'enabled': True}}
            '''
        else:
            edges_to_remove.append((source, target, key))

        

    #removing
    for source, target, key in edges_to_remove:
        g.remove_edge(source, target, key=key)
    print('nmr of directed edges', len(directed_edges_to_add))

    for target, source, key, data in undirected_edges_to_add:
        g.add_edge(target, source, key, **data)
        g[target][source][key]['hidden'] = True
        g[target][source][key]['id'] = f'{target} interacts with {source}'
        

        
    
    

    '''           
    REVER SE FAZ SENTIDO TER ISTO
    if add_reciprocal_edges:
        directed_edges_to_add = []
        for source, target, data in g.edges(data=True):
            if(data['interaction'] == 'interacts with') and (not g.has_edge(target,source)): #will add the opposite since these edges are undirected, when True
                directed_edges_to_add.append((target, source, data))
        g.add_edges_from(directed_edges_to_add) 
    



    # directed == True when i just want direct edges
    if directed:
        to_remove = [(source,target) for source, target, data in g.edges(data = True) if data['interaction'] == 'interacts with']
        g.remove_edges_from(to_remove)

        # remove isolates resulting from filtering
        isolates = list(nx.isolates(g))
        g.remove_nodes_from(isolates)'''    
    return g


            
    
   



        
            

 


