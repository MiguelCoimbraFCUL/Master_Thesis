from pathlib import Path
import gzip
import pandas as pd
import networkx as nx
import math
from load_network_utils import detect_delimiter, detect_delimiter_compressed


def ckn_to_networkx(edgesPath, nodePath, add_reciprocal_edges = False, directed = False):
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
                             create_using = nx.Graph(),
                             data = [
                                 ('interaction', str),
                                 ('irp_score', float),
                                 #('ConnectTF_Target', str),
                                 #('cis_elements', int),
                                 ('EdgeBetweenness',float)
                             ])


    if nodesCompressed:
        delimiter = detect_delimiter_compressed(nodesPath)
        node_df = pd.read_csv(nodePath, na_values = ['','null','NaN'], keep_default_na = False, sep = delimiter, compression = 'gzip')
    else:
        delimiter = detect_delimiter(nodesPath)
        node_df = pd.read_csv(nodePath, na_values = ['','null','NaN'], keep_default_na = False, sep = delimiter)
        
    
    
    
    
    mapping = {}
    for node, attrs in g.nodes(data=True):
        nodeS = node.strip('"')
        mapping.update({node:nodeS})
        
    g = nx.relabel_nodes(g,mapping)
    print(node_df.head())  # Displays the first 5 rows by default
    node_df.set_index('name', inplace = True)

    #turn db into a dict where the keys are the names and the values are the rest of the information
    nx.set_node_attributes(g, node_df.to_dict('index'))
    
    #way of stripping tring types information
    #create interval ranks for co-expression (irp score) 
    co_exp_rank_thresholds = {
    0.2: 4,
    0.4: 3,
    0.6: 2,
    0.8: 1,
    1.0: 0
    }
    
    for source, target, data in g.edges(data=True):
        if 'interaction' in data:
            data['interaction'] = data['interaction'].strip('"')
        if 'irp_score' in data:
            for threshold, co_exp_rank in co_exp_rank_thresholds.items():
                if data['irp_score'] <= threshold:
                    g[source][target]['co_exp_rank'] = co_exp_rank
                    break
                

    if add_reciprocal_edges:
        edges_to_add = []
        for source, target, data in g.edges(data=True):
            if(data['interaction'] == 'interacts with') and (not g.has_edge(target,source)): #will add the opposite since these edges are undirected, when True
                edges_to_add.append((target, source, data))
        g.add_edges_from(edges_to_add) 
    



    # directed == True when i just want direct edges
    if directed:
        to_remove = [(source,target) for source, taget, data in g.edges(data = True) if data['interaction'] == 'interacts with']
        g.remove_edges_from(to_remove)

        # remove isolates resulting from filtering
        isolates = list(nx.isolates(g))
        g.remove_nodes_from(isolates)

    
    
    return g


            
    
   



        
            

 


