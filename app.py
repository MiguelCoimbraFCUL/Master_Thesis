from flask import Flask, render_template, request, jsonify, after_this_request, send_file
import pandas as pd
from pathlib import Path
from utils import *
from load_network import *
from flask_cors import CORS, cross_origin
from pdfReport import PDFReport
import os
from io import BytesIO





base_dir = Path('../')
data_dir = base_dir / 'data'

ckn_edge_path = data_dir / 'updatedData/Clean_DEG_GCN36_TPM_phellem1defaultedge.csv'
ckn_node_path = data_dir / 'updatedData/Clean_DEG_GCN36_TPM_phellem1defaultnode.csv'


class CKN(object):
    def __init__(self):
        self.graph = None
        self.node_search_data = None 
        self.load()

    
    def load(self):
        if self.graph is None:
            self.graph = ckn_to_networkx(ckn_edge_path, ckn_node_path)
            self.node_search_data = get_autocomplete_node_data(self.graph)

            
ckn = CKN()

app = Flask(__name__)
CORS(app)



@app.route('/')
def main():
    ckn.load()
    return render_template('index.html')

# Search route to handle POST requests from the JS

@app.route('/', endpoint='index') #endpoint is necessary since two or more view functions with the same name (main)
def main():
    ckn.load()
    return render_template('index.html')

@app.route('/search', methods=['GET', 'POST'])
def search():
    
    try:
        # Retrieve the JSON data from the request
        data = request.get_json(force=False)
        print('data',data)
        
        if not data or 'nodes' not in data:
            return {'error': 'No nodes provided.'}, 400
        
        query_nodes = set(data['nodes']) # validNodes
        tf_ranks = list(data['ranks'])
        slideRange_co_exp = data['rangeSliderValue']
                
        # Check for valid nodes in the graph
        valid_nodes = query_nodes.intersection(set(ckn.graph.nodes()))
        valid_nodes = list(valid_nodes)

        if not valid_nodes:
            return {'error': 'No valid nodes found.'}, 400
        # If valid nodes exist, extract the subgraph
        subgraph = extract_shortest_paths(ckn.graph, valid_nodes)
        filter_edges_nodes(subgraph, valid_nodes, tf_ranks, slideRange_co_exp)
        return graph2json(subgraph, valid_nodes)

    except Exception as e:
        return {'error': f'Invalid query data: {str(e)}'}, 400
    
@app.route('/report', methods=['GET', 'POST'])
def generate_report():
    try:
        # Retrieve the JSON data from the request
        data = request.get_json(force=False)
        if not data or 'quried_nodes' not in data or 'tf_ranks' not in data or 'rangeSliderValue' not in data:
            return {'error': 'Not all data required provided.'}, 400
        quried_nodes = set(data['quried_nodes']) # validNodes
        tf_ranks = list(data['tf_ranks'])
        rangeSliderValue = data['rangeSliderValue']
        nodes_dict = data['nodes']
        edges_dict = data['edges']

        

        #generate pdf
        pdf = PDFReport(quried_nodes)
        pdf.add_page()

        pdf_file_path = 'gene_relation_report.pdf'
        
        # Add content to PDF
        pdf.add_summary(rangeSliderValue, tf_ranks)
        pdf.add_legend()
        pdf.add_edges_table(edges_dict)
        pdf.add_nodes_table(nodes_dict)
        pdf.output(pdf_file_path)
        pdf_bytes = BytesIO()
        byte_string = pdf.output(dest='S')  # Write PDF content to the BytesIO stream
        stream = BytesIO(byte_string)
        stream.seek(0)  # Move cursor to the start of the stream


        response = send_file(stream, as_attachment=True, download_name='gene_relation_report.pdf', mimetype='application/pdf')

        # Delete the file after sending
        '''@after_this_request
        def cleanup(response):
            try:
                os.remove(pdf_file_path)
            except Exception as e:
                print(f'Failed to delete {pdf_file_path}. Reason: {e}')
            return response'''
        return response
            
    except Exception as e:
        return {'error': f'Invalid data: {str(e)}'}, 500

    


@app.route('/get_node_data', methods=['GET', 'POST'])
def node_data():
    return ckn.node_search_data

@app.route('/expand', methods=['GET', 'POST'])
def expand():
    try:
        data = request.get_json(force=False)
        query_nodes = set(data.get('nodes'))
        all_nodes = set(data.get('all_nodes'))
        tf_ranks = list(data['ranks'])
        slideRange_co_exp = data['rangeSliderValue']
    except Exception as e:
        return {'error': f'Invalid query data: {str(e)}'}, 400
    subgraph, potentialEdges = expand_nodes(ckn.graph, list(query_nodes), all_nodes, tf_ranks, slideRange_co_exp)

    # write potential edges in JSON
    elist = []
    for fr, to, k, attrs in potentialEdges:
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
    json_data = graph2json(subgraph)
    json_data['network']['potential_edges'] = elist

    print(len(subgraph), len(potentialEdges))
    print(potentialEdges)
    return json_data


    # write potential edges in JSON

if __name__ == '__main__':
    app.run(port=5001,debug=True)