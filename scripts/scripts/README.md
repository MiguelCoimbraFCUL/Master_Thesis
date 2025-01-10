# Knowlage Network creation and Cork Oak Gene interactions Visualisation and Retrieval Tool

Welcome to the Cork Oak Gene Interactions Visualization Tool! This tool is designed to retrieve and visualize gene regulatory networks in *Quercus suber* (cork oak), providing insights into gene interactions.

## Features
- Generation of a Knowledge Network focused on gene interactions relevant to the secondary growth
of cork oak
 - Aggregation and preprocessing of RNA-seq expression data from diverse datasets
 - Generation of a gene regulatory network by combining co-expression networks and functional
    annotations to identify transcription factor / target key interactions.
- Web visualization and retrieval tool for cork oak gene interactions
 - Search query
 - Sets of filters allowing customized searches
 - Interactive graphic vizualisation
 - Export options

## Table of Contents
- [Usage](#usage)
- [Project Structure](#project-structure)

## Usage
:o

## Project Structure

### Additional Directories
- **./bioProject_pipeline.sh**

### 1. Aggregation and preprocessing of RNA-seq expression data

- **fetch_ncbi_BioP.sh**: Retrieves information about the Bioprojects gathered by the query.
- **prefetch.sh**: Retrieves RNA-seq data files from the Sequence Read Archive (SRA).
- **fasterq_dump.sh**: Converts SRA files into FASTQ format for downstream processing.
- **preprocessing.sh**: Executes trimming and quality control of reads using Trimmomatic and FastQC.
- **log_trim_reads.sh**: Logs the results of trimming operations to track preprocessing quality.
- **star_fc.sh**: Aligns RNA-seq reads using STAR and generates raw read counts using featureCounts.
- **log_star.sh**: Logs alignment statistics produced by the STAR aligner.
- **log_fc.sh**: Logs read count results and featureCounts statistics.
- **log_BioP_stats.sh**: Collects and summarizes statistics for each BioProject.
- **clean_BioP.sh**: Removes intermediate files and directories to free up storage space.
- **Raw_Counts_Processing.R**: Merges raw count tables from different samples into a single table.
- **Raw_Counts_normalization.R**: Normalizes the merged raw counts for downstream analysis and generates a distance matrix regarding the data retrieved.
- **Raw_Counts_PCA.R**: N sei de uso ?????????

 

### 2. Aggregation and preprocessing of RNA-seq expression data


