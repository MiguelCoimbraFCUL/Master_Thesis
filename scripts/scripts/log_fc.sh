#!/bin/bash
#This script processes a featureCounts summary file to extract the number of assigned and unassigned reads, adjusts the values for paired-end (PE) reads
#and logs the results into a CSV file for a specified BioProject.

# ./log_fc.sh /path/to/summary.txt format Bioproject
#------------------------------------------------------------------------------

RAW_READS_SUMMARY="$1"
FORMAT="$2"
BIOPROJECT="$3"

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"


printf "Assigned Reads \n" > $BASE_DIR/$BIOPROJECT/logs/a.csv
printf "Unassigned Reads \n" > $BASE_DIR/$BIOPROJECT/logs/u.csv

n_assigned_r=$(grep "Assigned" $RAW_READS_SUMMARY | grep -o '[[:digit:]]*')
n_unassigned_r=$(grep "Unassigned_NoFeatures" $RAW_READS_SUMMARY | grep -o '[[:digit:]]*')

if [ "$FORMAT" == "pe" ]; then 
    n_assigned_r=$(($n_assigned_r*2))
    n_unassigned_r=$(($n_unassigned_r*2))
fi

echo "$n_assigned_r" >> $BASE_DIR/$BIOPROJECT/logs/a.csv
echo "$n_unassigned_r" >> $BASE_DIR/$BIOPROJECT/logs/u.csv

paste $BASE_DIR/$BIOPROJECT/logs/a.csv $BASE_DIR/$BIOPROJECT/logs/u.csv > $BASE_DIR/$BIOPROJECT/logs/featureCounts_log.csv

rm $BASE_DIR/$BIOPROJECT/logs/a.csv
rm $BASE_DIR/$BIOPROJECT/logs/u.csv