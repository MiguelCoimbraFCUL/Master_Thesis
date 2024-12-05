#!/bin/bash
#This script consolidates logs from various RNA-seq processing steps into a single CSV file for a given BioProject.

# ./log_BioP_stats.sh Bioproject
#------------------------------------------------------------------------------bioP="$1"
bioP_dir="$HOME/data/$bioP/logs"
paste $bioP_dir/trimmomatic_log.csv $bioP_dir/STAR_log.csv $bioP_dir/featureCounts_log.csv > $bioP_dir/${bioP}_Statistics.csv
#rm $bioP_dir/trimmomatic_log.csv
#rm $bioP_dir/STAR_log.csv
#rm $bioP_dir/featureCounts_log.csv