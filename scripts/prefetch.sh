#!/bin/bash
#This script fetches SRA files for a given BioProject using the prefetch tool from NCBI's SRA Toolkit. 
#It runs the prefetch command in parallel for each SRR in the specified BioProject and logs the process.

# ./prefetch.sh Bioproject_accession

#------------------------------------------------------------------------------
# Path to the program prefetch
export PATH=$PATH:$HOME/sratoolkit.3.1.1-ubuntu64/bin

# Check if the BioProject name is provided as an argument
if [ -z "$1" ]; then
    # If not provided, prompt the user
    read -p "Enter the BioProject name: " BIOPROJECT
else
    # Use the argument as the BioProject name
    BIOPROJECT="$1"
fi

# Define the file that contains SRR numbers for the given BioProject
SRA_FILE="../bioProjects_info/${BIOPROJECT}.txt"

# Ensure that the SRA file exists
if [ ! -f "$SRA_FILE" ]; then
    echo "SRA file for BioProject '$BIOPROJECT' not found!"
    exit 1
fi

# Create the main directory with the BioProject name
MAIN_DIR="$HOME/data/$BIOPROJECT"
mkdir -p $MAIN_DIR/logs
PREFETCH_DIR="$MAIN_DIR/prefetch"


# Ensure the directories exist
mkdir -p "$PREFETCH_DIR"


# Define the log file path
LOG_FILE="$MAIN_DIR/logs/prefetch_log.txt"

# Count the number of SRR entries in the SRA file and set the number of parallel jobs
PARALLEL_JOBS=$(wc -l < "$SRA_FILE")
echo "Number of parallel jobs set to: $PARALLEL_JOBS"

# Run the prefetch command in parallel, specifying the output directory as $PREFETCH_DIR
nohup bash -c "cat $SRA_FILE | parallel -j $PARALLEL_JOBS 'prefetch --max-size 45G --output-directory $PREFETCH_DIR {} && echo \"{} successfully prefetched.\" || echo \"Failed to prefetch {}.\"'" > "$LOG_FILE" 2>&1 &

# Notify the user
echo "Prefetching in parallel has started in the background. Check the log file at '$LOG_FILE' for the output."
