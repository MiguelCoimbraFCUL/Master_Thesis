#!/bin/bash
#This script performs preprocessing on RNA-seq data by running FastQC and Trimmomatic tools. 
#It processes single-end (SE) or paired-end (PE) reads, trimming low-quality sequences and running FastQC quality checks.

# ./fasterq_dump.sh Bioproject__accession format('se' or 'pe')
#------------------------------------------------------------------------------
# Set paths to FastQC and Trimmomatic
export PATH=$PATH:$HOME/FastQC
trim_path="$HOME/Trimmomatic-0.39/trimmomatic-0.39.jar"
adatpers_PE="$HOME/Trimmomatic-0.39/adapters/TruSeq3-PE.fa"
adatpers_SE="$HOME/Trimmomatic-0.39/adapters/TruSeq3-SE.fa"
BASE_DIR="$HOME/data"




# Check if the BioProject name is provided as an argument
if [ -z "$1" ]; then
    # If not provided, prompt the user
    read -p "Enter the BioProject name: " BIOPROJECT
else
    # Use the argument as the BioProject name
    BIOPROJECT="$1"
fi

# Check if the BioProject directory exists
if [ ! -d "$BASE_DIR/$BIOPROJECT" ]; then
    echo "Error: BioProject directory '$BIOPROJECT' not found inside '$BASE_DIR'. Please check the directory name."
    exit 1
fi

if [ ! -s "$BASE_DIR/$BIOPROJECT/logs/trimmomatic_log.csv" ]; then
    printf "Sample \t Total Reads \t Discarded Reads \t Trimmed Reads (perc) \n" > $BASE_DIR/$BIOPROJECT/logs/trimmomatic_log.csv
fi

# Create necessary directories
mkdir -p $BASE_DIR/$BIOPROJECT/preprocessing/fastqc/raw
mkdir -p $BASE_DIR/$BIOPROJECT/preprocessing/fastqc/filtered
mkdir -p $BASE_DIR/$BIOPROJECT/preprocessing/hq_reads

# Check if the format is provided as an argument
if [ -z "$2" ]; then
    # If not provided, prompt the user
    read -p "Enter the format of the reads (se or pe) for BioProject $BIOPROJECT: " FORMAT
else
    # Use the argument as the format
    FORMAT="$2"
fi

BIOPROJECT_DIR="$BASE_DIR/$BIOPROJECT"

# Check if the BioProject directory exists
if [ ! -d "$BIOPROJECT_DIR" ]; then
    echo "Error: BioProject directory '$BIOPROJECT' not found."
    exit 1
fi

SAMPLES_FILE="$HOME/data/bioProjects_info/$BIOPROJECT.txt"
FASTQ_DIR="$BIOPROJECT_DIR/fastq"

# Run FastQC for each sample
for fastqFile in "$FASTQ_DIR"/*; do
    if [ -f "$fastqFile" ]; then
        sample=$(basename "$fastqFile" .fastq)
        echo "Starting FastQC for $sample"
        echo "fastqc -t 6 -o $BASE_DIR/$BIOPROJECT/preprocessing/fastqc/raw $fastqFile"
        fastqc -t 6 -o "$BASE_DIR/$BIOPROJECT/preprocessing/fastqc/raw" "$fastqFile"

    fi
done


if [ "$FORMAT" == "se" ]; then  
    # Loop through single-end files and run Trimmomatic
    for fastqFile in "$FASTQ_DIR"/*; do
        if [ -f "$fastqFile" ]; then
            sample=$(basename "$fastqFile" .fastq)
            echo "Starting Trimmomatic for $sample"
            java -jar "$trim_path" SE \
                -threads 20 \
                -trimlog "$BASE_DIR/$BIOPROJECT/preprocessing/hq_reads/$sample.log" \
                "$fastqFile" \
                "$BASE_DIR/$BIOPROJECT/preprocessing/hq_reads/$sample.filtered.fq.gz" \
                ILLUMINACLIP:"$adatpers_SE":2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:50
        fi
    done
    # Second run of FastQC for the filtered reads

    for file in $BASE_DIR/$BIOPROJECT/preprocessing/hq_reads/*.fq.gz; do
        if [ -f "$file" ]; then
            sample="$(basename $file .filtered.fq.gz)"
            echo "Starting FastQC for filtered $sample read: $file"
            
            fastqc -t 6 -o "$BASE_DIR/$BIOPROJECT/preprocessing/fastqc/filtered" "$file"
        else
            sample="$(basename $file .filtered.fq.gz)"
            echo "No filtered reads found for sample $sample."
        fi
    done

elif [ "$FORMAT" == "pe" ]; then  
    # Process paired-end samples
    while IFS= read -r SRR; do
        sampleR1="$FASTQ_DIR/${SRR}_1.fastq"
        sampleR2="$FASTQ_DIR/${SRR}_2.fastq"
        echo "Starting Trimmomatic for $SRR"
        java -jar "$trim_path" PE \
            -threads 20 \
            -trimlog "$BASE_DIR/$BIOPROJECT/preprocessing/hq_reads/$SRR.log" \
            "$sampleR1" \
            "$sampleR2" \
            -baseout "$BASE_DIR/$BIOPROJECT/preprocessing/hq_reads/$SRR.filtered.fq.gz" \
            ILLUMINACLIP:"$adatpers_PE":2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:50
           
    done < "$SAMPLES_FILE"

    
     # Second run of FastQC for the filtered reads

    # Run FastQC for each sample
    for file in $BASE_DIR/$BIOPROJECT/preprocessing/hq_reads/*P.fq.gz; do
        if [ -f "$file" ]; then
            sample="$(echo $filename | cut -d '.' -f 1)"
            echo "Starting FastQC for filtered $sample read: $file"
            fastqc -t 6 -o "$BASE_DIR/$BIOPROJECT/preprocessing/fastqc/filtered" "$file"
        else
            sample="$(echo $filename | cut -d '.' -f 1)"
            echo "No filtered reads found for sample $sample."
        fi
    done
fi

log_trim_reads.sh $BASE_DIR/$BIOPROJECT/preprocessing/hq_reads/$SRR.log $FORMAT $BIOPROJECT $SRR