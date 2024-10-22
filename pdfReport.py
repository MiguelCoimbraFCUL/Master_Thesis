from fpdf import *
from datetime import datetime

#cell:
# width - height - text - border - linebreak - alignement
#   0       10      ...      0/1      0/1         L C R

from fpdf import FPDF, XPos, YPos
from datetime import datetime

class PDFReport(FPDF):

    def __init__(self, queried_genes):
        super().__init__()
        self.queried_genes = queried_genes

    def header(self):
        queried_genes_strings = [str(gene) for gene in self.queried_genes]
        self.set_font('Helvetica', 'B', 14)  # Use Helvetica
        self.cell(0, 10, f'Gene Interaction Report - {", ".join(queried_genes_strings)}', new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        self.cell(0, 10, f'Date: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}', new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font('Helvetica', 'I', 8)  # Use Helvetica
        self.cell(0, 10, f'Page {self.page_no()}', new_x=XPos.RIGHT, new_y=YPos.TOP)

    def add_summary(self, irp_score, tf_rank):
        if len(tf_rank) == 0:
            tf_rank = [0, 1, 2, 3]            
        self.set_font('Helvetica', 'B', 12)  # Use Helvetica
        self.cell(0, 6, 'Analysis Summary', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_font('Helvetica', '', 10)  # Use Helvetica
        self.cell(0, 6, f'- Minimum IRP Score: {irp_score}', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        tf_rank_strings = [str(rank) for rank in tf_rank]
        self.cell(0, 6, f'- Trancription factor Ranks searched: {", ".join(tf_rank_strings)}', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(10)

    def add_legend(self):
        self.set_font('Helvetica', 'B', 10)  # Use Helvetica
        self.cell(0, 6, 'TF Ranks Legend:', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_font('Helvetica', '', 8)  # Use Helvetica
        legend_items = [
            '- 0 : Only Co-Expression Relations',
            '- 1 : Only Presence of cis-elements in the promoter region of the target',
            '- 2 : Only ConnecTF data',
            '- 3 : Both presence of cis-elements and ConnecTF data'
        ]
        for item in legend_items:
            self.cell(0, 6, item, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(5)
    
    def add_edges_table(self):
        self.set_font('Helvetica', 'B', 10)
        # Column headers
        headers = ['Source', 'Target', 'IRP Score', 'TF Rank', 'Directed']
        col_widths = [40, 40, 30, 30, 30]  # Adjust the widths as needed

        # Header row
        for header, width in zip(headers, col_widths):
            self.cell(width, 10, header, border=1, align='C')
        self.ln()



#generate PDF
pdf = PDFReport(['LOC1','loc2'])
pdf.add_page()

# Add content to PDF
pdf.add_summary(irp_score="0.8", tf_rank=["0", "1"])
pdf.add_legend()
pdf.add_edges_table()

pdf.output('gene_relation_report.pdf')


'''
required:

quried_genes
iprscore rank
tfrank


'''