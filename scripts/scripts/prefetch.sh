#!/bin/bash
# This script fetches SRA files for a given BioProject using the prefetch tool from NCBI's SRA Toolkit.
# It runs the prefetch command in parallel for each SRR in the specified BioProject and logs the process.

# ./prefetch.sh Bioproject_accession

#------------------------------------------------------------------------------ 


BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$(cd "$(dirname "$0")/../../bin" && pwd)"

# Path to the program prefetch
export PATH="$BIN_DIR/sratoolkit.3.1.1-ubuntu64/bin:$PATH"

# Check if the BioProject name is provided as an argument
if [ -z "$1" ]; then
    # If not provided, prompt the user
    read -p "Enter the BioProject name: " BIOPROJECT
else
    # Use the argument as the BioProject name
    BIOPROJECT="$1"
fi

# Define the file that contains SRR numbers for the given BioProject
SRA_FILE="$BASE_DIR/bioProjects_info/${BIOPROJECT}.txt"

# Ensure that the SRA file exists
if [ ! -f "$SRA_FILE" ]; then
    echo "SRA file for BioProject '$BIOPROJECT' not found!"
    exit 1
fi

# Create the main directory with the BioProject name
MAIN_DIR="$BASE_DIR/$BIOPROJECT"
mkdir -p $MAIN_DIR/logs
PREFETCH_DIR="$MAIN_DIR/prefetch"

# Ensure the directories exist
mkdir -p "$PREFETCH_DIR"

# Define the log file path
LOG_FILE="$MAIN_DIR/logs/prefetch_log.txt"

# Count the number of SRR entries in the SRA file and set the number of parallel jobs
PARALLEL_JOBS=$(wc -l < "$SRA_FILE")
if [ "$PARALLEL_JOBS" -gt 14 ]; then
    PARALLEL_JOBS=14
fi

echo "Number of parallel jobs set to: $PARALLEL_JOBS"
# Run the prefetch command in parallel, specifying the output directory as $PREFETCH_DIR
cat "$SRA_FILE" | parallel -j "$PARALLEL_JOBS" "prefetch --max-size 45G --output-directory \"$PREFETCH_DIR\" {} && echo \"{} successfully prefetched.\" || echo \"Failed to prefetch {}.\"" >> "$LOG_FILE" 2>&1

# Notify the user when done
echo "Prefetching completed. Check the log file at '$LOG_FILE' for details."