#!/bin/bash
#Parses a STAR log file to extract alignment metrics such as uniquely mapped reads and unmapped reads.
#Then logs these metrics into a CSV file for a given BioProject.

# ./log_star.sh path/to/sample.Log.final.out BioProject
#------------------------------------------------------------------------------
# Extract sample name
sample_name=$(basename "$1" .Log.final.out)
echo $sample_name
BIOPROJECT="$2"

# Extract metrics from the STAR log file
input_reads_n=$(grep "Number of input reads" "$1" | grep -o '[[:digit:]]*')
uniq_map_reads_n=$(grep "Uniquely mapped reads number" "$1" | grep -o '[[:digit:]]*')
uniq_map_reads_double_n=$((uniq_map_reads_n * 2))
uniq_map_reads_p=$(grep "Uniquely mapped reads %" "$1" | grep -o '[[:digit:]][[:digit:]]*.[[:digit:]]*')
mm_um_cr_n=$((input_reads_n - uniq_map_reads_n))
unmapped_reads_short=$(grep "Number of reads unmapped: too short" "$1" | grep -o '[[:digit:]]*')
unmapped_reads_other=$(grep "Number of reads unmapped: other" "$1" | grep -o '[[:digit:]]*')
unmapped_reads_n=$((unmapped_reads_short + unmapped_reads_other))

printf "%s\t%d\t%s\t%d\t%d\n" "$sample_name" "$uniq_map_reads_double_n" "$uniq_map_reads_p" "$mm_um_cr_n" "$unmapped_reads_n" >> $HOME/data/$BIOPROJECT/logs/STAR_log.csv

