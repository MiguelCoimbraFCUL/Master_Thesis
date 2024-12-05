#!/bin/bash
#Automates genome indexing, read alignment with STAR, and featureCounts processing for single-end (se) or paired-end (pe) RNA-seq data.
#Logs summary statistics for a specified BioProject.

# ./star_fc.sh BioProject format(se or pe)
#------------------------------------------------------------------------------
export PATH=$PATH:$HOME/STAR-2.7.11b/source
export PATH=$PATH:$HOME/subread-2.0.8-Linux-x86_64/bin
export PATH=$PATH:$HOME/bamtools-2.5.2


mkdir -p $HOME/data/genome
mkdir -p $HOME/data/genome/genome_index
mkdir -p $HOME/data/genome/genome_annotation
GENOME_DIR=$HOME/data/genome
GENOME_IDX_DIR=$HOME/data/genome/genome_index
GENOME_ANN_DIR=$HOME/data/genome/genome_annotation

# Download the genome files if they are not already present
if [ ! -f "$GENOME_DIR/cork_oak_genome.fna" ]; then
    echo "Downloading genome FASTA file..."
    wget -O $GENOME_DIR/cork_oak_genome.fna.gz https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/906/115/GCF_002906115.3_Cork_oak_2.0/GCF_002906115.3_Cork_oak_2.0_genomic.fna.gz
    gunzip $GENOME_DIR/cork_oak_genome.fna.gz
fi

if [ ! -f "$GENOME_ANN_DIR/cork_oak_genome_annotation.gtf" ]; then
    echo "Downloading genome annotation file..."
    wget -O $GENOME_ANN_DIR/cork_oak_genome_annotation.gtf.gz https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/906/115/GCF_002906115.3_Cork_oak_2.0/GCF_002906115.3_Cork_oak_2.0_genomic.gtf.gz
    gunzip $GENOME_ANN_DIR/cork_oak_genome_annotation.gtf.gz
fi

if [ -z "$1" ]; then
    # If not provided, prompt the user
    read -p "Enter the BioProject name: " BIOPROJECT
else
    # Use the argument as the BioProject name
    BIOPROJECT="$1"
fi
# Check if the BioProject directory exists
if [ ! -d "$HOME/data/$BIOPROJECT" ]; then
    echo "Error: BioProject directory '$BIOPROJECT' not found inside '$HOME/data'. Please check the directory name."
    exit 1
fi

if [ ! -s "$HOME/data/$BIOPROJECT/logs/STAR_log.csv" ]; then
    printf "Unique Mapped Reads \t Uniq Mapped Reads (perc) \t Total Unmapped Reads \t Unmapped Reads (Anotation) \n" > $HOME/data/$BIOPROJECT/logs/STAR_log.csv
fi

# Check if the format is provided as an argument
if [ -z "$2" ]; then
    # If not provided, prompt the user
    read -p "Enter the format of the reads (se or pe) for BioProject $BIOPROJECT: " FORMAT
else
    # Use the argument as the format
    FORMAT="$2"
fi


GENOME_FASTA=$GENOME_DIR/cork_oak_genome.fna
GENOME_ANN=$GENOME_ANN_DIR/cork_oak_genome_annotation.gtf
#gene Indexes
if [ ! -f "$GENOME_IDX_DIR/chrLength.txt" ]; then
    echo "Genome index directory is empty. Generating genome index with STAR..."
    STAR --runThreadN 10 \
      --runMode genomeGenerate \
      --genomeDir $GENOME_IDX_DIR \
      --genomeFastaFiles $GENOME_FASTA \
      --sjdbGTFfile $GENOME_ANN \
      --sjdbGTFtagExonParentTranscript Parent \
      --genomeSAindexNbases 13
    echo "Genome indexing completed."
fi

if [ "$FORMAT" == "se" ]; then  
    for file in $HOME/data/$BIOPROJECT/preprocessing/hq_reads/*.fq.gz; do
        sample=$(basename $file .filtered.fq.gz)
        echo "Starting STAR for $sample"
        mkdir -p $HOME/data/$BIOPROJECT/aligned_reads

        STAR --runThreadN 15 \
        --genomeDir $GENOME_IDX_DIR \
        --readFilesIn $file \
        --outFileNamePrefix $HOME/data/$BIOPROJECT/aligned_reads/$sample. \
        --twopassMode Basic \
        --readFilesCommand gunzip -c \
        --outReadsUnmapped Fastx \
        --outFilterIntronMotifs RemoveNoncanonical \
        --alignIntronMax 100000 \
        --outSAMtype BAM Unsorted

       $HOME/data/scripts/log_star.sh $HOME/data/$BIOPROJECT/aligned_reads/$sample.Log.final.out $BIOPROJECT

        # Sort BAM file with samtools
            echo "Sorting BAM file for $sample"
            samtools sort -@ 5 \
                $HOME/data/$BIOPROJECT/aligned_reads/${sample}.Aligned.out.bam \
                -o $HOME/data/$BIOPROJECT/aligned_reads/${sample}_sorted.bam

            #Remove the unsorted BAM file to save space
            #rm $HOME/data/$BIOPROJECT/aligned_reads/${sample}.Aligned.out.bam
    done

    
    bam_list=""
    for bam_file in $HOME/data/$BIOPROJECT/aligned_reads/*_sorted.bam; do
        bam_list+=" $bam_file"
    done

    featureCounts -T 5 \
    -t exon \
    -g gene \
    -a $GENOME_ANN \
    -o $HOME/data/$BIOPROJECT/logs/${BIOPROJECT}_raw_counts.txt $bam_list

elif [ "$FORMAT" == "pe" ]; then
    ls -1 $HOME/data/$BIOPROJECT/preprocessing/hq_reads/*P.fq.gz | awk -F'.' '{print $1}' | sort -u > $HOME/data/$BIOPROJECT/preprocessing/hq_reads/filtered_samples.txt
    r1_suf=".filtered_1P.fq.gz"
    r2_suf=".filtered_2P.fq.gz" 
    #Running STAR with the samples
    while read -r line; do
        sample1="${line}${r1_suf}"
        sample2="${line}${r2_suf}"
        sample=$(basename $line)
        echo "Starting STAR for $sample"
        mkdir -p $HOME/data/$BIOPROJECT/aligned_reads

        STAR --runThreadN 15 \
        --genomeDir $GENOME_IDX_DIR \
        --readFilesIn $sample1 $sample2 \
        --outFileNamePrefix $HOME/data/$BIOPROJECT/aligned_reads/$sample. \
        --twopassMode Basic \
        --readFilesCommand gunzip -c \
        --outReadsUnmapped Fastx \
        --outFilterIntronMotifs RemoveNoncanonical \
        --alignIntronMax 100000 \
        --outSAMtype BAM Unsorted

        # Sort BAM file with samtools
        echo "Sorting BAM file for $sample"
        samtools sort -@ 5 \
            $HOME/data/$BIOPROJECT/aligned_reads/${sample}.Aligned.out.bam \
            -o $HOME/data/$BIOPROJECT/aligned_reads/${sample}_sorted.bam

        # Remove the unsorted BAM file to save space        
        $HOME/data/scripts/log_star.sh $HOME/data/$BIOPROJECT/aligned_reads/$sample.Log.final.out $BIOPROJECT

    done < "$HOME/data/$BIOPROJECT/preprocessing/hq_reads/filtered_samples.txt"


    bam_list=""
    for bam_file in $HOME/data/$BIOPROJECT/aligned_reads/*_sorted.bam; do
        bam_list+=" $bam_file"
    done

    featureCounts -T 5 \
    -p --countReadPairs \
    -t exon \
    -g gene \
    -a $GENOME_ANN \
    -o $HOME/data/$BIOPROJECT/logs/${BIOPROJECT}_raw_counts.txt $bam_list

else
    echo "Invalid format specified: $FORMAT. Available formats are (se ; pe)"
    exit 1
fi
                            
$HOME/data/scripts/log_fc.sh $HOME/data/$BIOPROJECT/logs/${BIOPROJECT}_raw_counts.txt.summary $FORMAT $BIOPROJECT
$HOME/data/scripts/log_BioP_stats.sh ${BIOPROJECT}