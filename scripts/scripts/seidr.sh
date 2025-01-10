#!/bin/bash
BIN_DIR="$(cd "$(dirname "$0")/../../bin" && pwd)"
export PATH="$BIN_DIR/seidr/build:$PATH"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
cat << EOF

Usage: $0 [options]

A Crowd Network generator for visualization of Co-Expression Networks.

Options:
  -h      Show this help message and exit.
  -f      Path to the file containing the Raw_Counts.txt table (delimiter: " ").
  -n      Number of threads to use for the Seidr run.
  -a      Aggregation method for crowd network (default: "irp").
  -o      Output directory for generated files and name of the output network.txt file (default: "seidr_output").
  -p      P-value threshold (default: 1.28, approx. 10%). For 5% use 1.64, and for 1% use 2.32.
  -d      Depth level for network generation. Higher depth increases runtime but extracts more information (default: "SLOW").
  -t      Path to a file containing a list of target genes (one gene per row). Used for generating a Targeted Network.
  -c      Cutoff value for the crowd network.
  -s      Generate additional statistics files:
            - network_stats.txt (overall network statistics)
            - network_nodestats.txt (node-level statistics)
  -e      Output an additional file with only the edge correlation scores.

Extra Information:
    There are currently four methods of aggregation implemented: (-m borda, -m top, -m top2, -m irp(default))

Examples:
    POR AQUI FORMA DE CORRER
EOF
}

printf "\n\n ----------------------------- STARTING THE SEIDR SCRIPT ------------------------------- \n\n"

while getopts "h:f:n:a:o:p:d:t:c:s:e:" OPTION
do
  case $OPTION in
    h) usage; exit 1;;
    f) rawcountsfile=$OPTARG;;
    n) thread=$OPTARG;;
    a) aggregate=$OPTARG;;
    o) outdir=$OPTARG;;
    p) pvalue=$OPTARG;;
    d) depth=$OPTARG;;
    t) target=$OPTARG;;
    c) cutoff=$OPTARG;;
    s) stats=$OPTARG;;
    e) edgecorscores=$OPTARG;;
    ?) usage; exit;;
  esac
done

set_default_values

# --------------------------------------------------------- MAIN CODE -------------------------------------------------------

mkdir -p $outdir

#This script receives a Raw_Counts.txt and outputs an expression.tsv and a genes.txt file to the specified outdir.
#These two files are the base material for all calculus for the Seidr crowd network generation toolkit.

raw_counts_normalization_seidr.R --rawcountsfile $rawcountsfile --output $outdir


#for more information -> https://seidr.readthedocs.io/en/latest/source/getting_started/getting_started.html

printf "\n\n | --------------------- Started computation with $thread threads and a $depth depth ---------------------- |\n\n"

#Checks if the network to be generated is in targeted mode or not
if [ $target == 'FALSE' ]
then


# FAST
printf "Calculating the Pearson Correlation scores 'fast'.\n"
correlation -m pearson -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/pearson_scores.tsv
seidr import -A -r -u -n PEARSON -o $BASE_DIR/$outdir/pearson_scores.sf -F lm -i $BASE_DIR/$outdir/pearson_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Spearman Correlation scores 'fast'.\n"
correlation -m spearman -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt
seidr import -A -r -u -n SPEARMAN -o $BASE_DIR/$outdir/spearman_scores.sf -F lm -i $BASE_DIR/$outdir/spearman_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the PCorrelation scores 'fast'.\n"
pcor -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt
seidr import -A -r -u -n PCOR -o $BASE_DIR/$outdir/pcor_scores.sf -F lm -i $BASE_DIR/$outdir/pcor_scores.tsv -g $BASE_DIR/$outdir/genes.txt

#MEDIUM
if [ $depth == 'MEDIUM' ] || [ $depth == 'SLOW' ] || [ $depth == 'VERY_SLOW' ]
then

printf "Calculating the RAW scores 'medium'.\n"
mi -m RAW -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/mi_scores.tsv
seidr import -r -u -n MI -o $BASE_DIR/$outdir/mi_scores.sf -F lm -i $BASE_DIR/$outdir/mi_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the CLR scores 'medium'.\n"
mi -m CLR -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -M $BASE_DIR/$outdir/mi_scores.tsv -o $BASE_DIR/$outdir/clr_scores.tsv
seidr import -r -u -z -n CLR -o $BASE_DIR/$outdir/clr_scores.sf -F lm -i $BASE_DIR/$outdir/clr_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the ARACNE scores 'medium'.\n"
mi -m ARACNE -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -M $BASE_DIR/$outdir/mi_scores.tsv -o $BASE_DIR/$outdir/aracne_scores.tsv
seidr import -r -u -z -n ARACNE -o $BASE_DIR/$outdir/aracne_scores.sf -F lm -i $BASE_DIR/$outdir/aracne_scores.tsv -g $BASE_DIR/$outdir/genes.txt
fi

#SLOW
if [ $depth == 'SLOW' ] || [ $depth == 'VERY_SLOW' ]
then

printf "Calculating the Narromi scores 'slow'\n"
narromi -O $thread -m interior-point -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/narromi_scores.tsv
seidr import -r -z -n NARROMI -o $BASE_DIR/$outdir/narromi_scores.sf -F m -i $BASE_DIR/$outdir/narromi_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Plsnet scores 'slow'\n"
plsnet -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/plsnet_scores.tsv
seidr import -r -z -n PLSNET -o $BASE_DIR/$outdir/plsnet_scores.sf -F m -i $BASE_DIR/$outdir/plsnet_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the LLR-Ensemble scores 'slow'\n"
llr-ensemble -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/llr_scores.tsv
seidr import -r -z -n LLR -o $BASE_DIR/$outdir/llr_scores.sf -F m -i $BASE_DIR/$outdir/llr_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the SVM-Ensemble scores 'slow'\n"
svm-ensemble -O $thread -k POLY -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/svm_scores.tsv
seidr import -r -z -n SVM -o $BASE_DIR/$outdir/svm_scores.sf -F m -i $BASE_DIR/$outdir/svm_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Genie3 scores 'slow'.\n"
genie3 -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/genie3_scores.tsv
seidr import -r -z -n GENIE3 -o $BASE_DIR/$outdir/genie3_scores.sf -F m -i $BASE_DIR/$outdir/genie3_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Tigress scores 'slow'\n"
tigress -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/tigress_scores.tsv
seidr import -r -z -n TIGRESS -o $BASE_DIR/$outdir/tigress_scores.sf -F m -i $BASE_DIR/$outdir/tigress_scores.tsv -g $BASE_DIR/$outdir/genes.txt
fi

#VERY_SLOW
if [ $depth == 'VERY_SLOW' ]
then

printf "Calculating the El-Ensemble scores 'very slow'.\n"
el-ensemble -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/elnet_scores.tsv
seidr import -r -z -n ELNET -o $BASE_DIR/$outdir/elnet_scores.sf -F m -i $BASE_DIR/$outdir/elnet_scores.tsv -g $BASE_DIR/$outdir/genes.txt
fi

else

#Running the Algorithms in targeted mode

# FAST
printf "Calculating the Pearson Correlation scores 'fast'.\n"
correlation -t $target -m pearson -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/pearson_scores.tsv
seidr import -A -r -u -n PEARSON -o $BASE_DIR/$outdir/pearson_scores.sf -F el -i $BASE_DIR/$outdir/pearson_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Spearman Correlation scores 'fast'.\n"
correlation -t $target -m spearman -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/spearman_scores.tsv
seidr import -A -r -u -n SPEARMAN -o $BASE_DIR/$outdir/spearman_scores.sf -F el -i $BASE_DIR/$outdir/spearman_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the PCorrelation scores 'fast'.\n"
pcor -t $target -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/pcor_scores.tsv
seidr import -A -r -u -n PCOR -o $BASE_DIR/$outdir/pcor_scores.sf -F el -i $BASE_DIR/$outdir/pcor_scores.tsv -g $BASE_DIR/$outdir/genes.txt

#MEDIUM
if [ $depth == 'MEDIUM' ] || [ $depth == 'SLOW' ] || [ $depth == 'VERY_SLOW' ]
then

printf "Calculating the RAW scores 'medium'.\n"
mi -t $target -m RAW -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -M $BASE_DIR/$outdir/mi_full_scores.tsv -o $BASE_DIR/$outdir/mi_scores.tsv
seidr import -r -u -n MI -o $BASE_DIR/$outdir/mi_scores.sf -F el -i $BASE_DIR/$outdir/mi_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the CLR scores 'medium'.\n"
mi -t $target -m CLR -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -M $BASE_DIR/$outdir/mi_full_scores.tsv -o $BASE_DIR/$outdir/clr_scores.tsv
seidr import -r -u -z -n CLR -o $BASE_DIR/$outdir/clr_scores.sf -F el -i $BASE_DIR/$outdir/clr_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the ARACNE scores 'medium'.\n"
mi -t $target -m ARACNE -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -M $BASE_DIR/$outdir/mi_full_scores.tsv -o $BASE_DIR/$outdir/aracne_scores.tsv
seidr import -r -u -z -n ARACNE -o $BASE_DIR/$outdir/aracne_scores.sf -F el -i $BASE_DIR/$outdir/aracne_scores.tsv -g $BASE_DIR/$outdir/genes.txt
fi

#SLOW
if [ $depth == 'SLOW' ] || [ $depth == 'VERY_SLOW' ]
then

printf "Calculating the Narromi scores 'slow'\n"
narromi -t $target -O $thread -m interior-point -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/narromi_scores.tsv
seidr import -r -z -n NARROMI -o $BASE_DIR/$outdir/narromi_scores.sf -F el -i $BASE_DIR/$outdir/narromi_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Plsnet scores 'slow'\n"
plsnet -t $target -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/plsnet_scores.tsv
seidr import -r -z -n PLSNET -o $BASE_DIR/$outdir/plsnet_scores.sf -F el -i $BASE_DIR/$outdir/plsnet_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the LLR-Ensemble scores 'slow'\n"
llr-ensemble -t $target -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/llr_scores.tsv
seidr import -r -z -n LLR -o $BASE_DIR/$outdir/llr_scores.sf -F el -i $BASE_DIR/$outdir/llr_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the SVM-Ensemble scores 'slow'\n"
svm-ensemble -t $target -O $thread -k POLY -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/svm_scores.tsv
seidr import -r -z -n SVM -o $BASE_DIR/$outdir/svm_scores.sf -F el -i $BASE_DIR/$outdir/svm_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Genie3 scores 'slow'.\n"
genie3 -t $target -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/genie3_scores.tsv
seidr import -r -z -n GENIE3 -o $BASE_DIR/$outdir/genie3_scores.sf -F el -i $BASE_DIR/$outdir/genie3_scores.tsv -g $BASE_DIR/$outdir/genes.txt
printf "Calculating the Tigress scores 'slow'\n"
tigress -t $target -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/tigress_scores.tsv
seidr import -r -z -n TIGRESS -o $BASE_DIR/$outdir/tigress_scores.sf -F el -i $BASE_DIR/$outdir/tigress_scores.tsv -g $BASE_DIR/$outdir/genes.txt
fi

#VERY_SLOW
if [ $depth == 'VERY_SLOW' ]
then

printf "Calculating the El-Ensemble scores 'very slow'.\n"
el-ensemble -t $target -O $thread -i $BASE_DIR/$outdir/expression.tsv -g $BASE_DIR/$outdir/genes.txt -o $BASE_DIR/$outdir/elnet_scores.tsv
seidr import -r -z -n ELNET -o $BASE_DIR/$outdir/elnet_scores.sf -F el -i $BASE_DIR/$outdir/elnet_scores.tsv -g $BASE_DIR/$outdir/genes.txt
fi

fi

#Aggregating the networks

#FAST
if [ $depth == 'FAST' ]; then seidr aggregate -o $BASE_DIR/$outdir/network.sf -m $aggregate $BASE_DIR/$outdir/pcor_scores.sf $BASE_DIR/$outdir/pearson_scores.sf $BASE_DIR/$outdir/spearman_scores.sf; fi

#MEDIUM
if [ $depth == 'MEDIUM' ]; then seidr aggregate -o $BASE_DIR/$outdir/network.sf -m $aggregate $BASE_DIR/$outdir/aracne_scores.sf $BASE_DIR/$outdir/clr_scores.sf $BASE_DIR/$outdir/mi_scores.sf $BASE_DIR/$outdir/pcor_scores.sf $BASE_DIR/$outdir/pearson_scores.sf $BASE_DIR/$outdir/spearman_scores.sf; fi

#SLOW
if [ $depth == 'SLOW' ]; then seidr aggregate -o $BASE_DIR/$outdir/network.sf -m $aggregate $BASE_DIR/$outdir/aracne_scores.sf $BASE_DIR/$outdir/clr_scores.sf $BASE_DIR/$outdir/genie3_scores.sf $BASE_DIR/$outdir/llr_scores.sf $BASE_DIR/$outdir/mi_scores.sf $BASE_DIR/$outdir/narromi_scores.sf $BASE_DIR/$outdir/pcor_scores.sf $BASE_DIR/$outdir/pearson_scores.sf $BASE_DIR/$outdir/plsnet_scores.sf $BASE_DIR/$outdir/spearman_scores.sf $BASE_DIR/$outdir/svm_scores.sf $BASE_DIR/$outdir/tigress_scores.sf; fi

#VERY SLOW
if [ $depth == 'VERY_SLOW' ]; then seidr aggregate -o $BASE_DIR/$outdir/network.sf -m $aggregate $BASE_DIR/$outdir/aracne_scores.sf $BASE_DIR/$outdir/clr_scores.sf $BASE_DIR/$outdir/elnet_scores.sf $BASE_DIR/$outdir/genie3_scores.sf $BASE_DIR/$outdir/llr_scores.sf $BASE_DIR/$outdir/mi_scores.sf $BASE_DIR/$outdir/narromi_scores.sf $BASE_DIR/$outdir/pcor_scores.sf $BASE_DIR/$outdir/pearson_scores.sf $BASE_DIR/$outdir/plsnet_scores.sf $BASE_DIR/$outdir/spearman_scores.sf $BASE_DIR/$outdir/svm_scores.sf $BASE_DIR/$outdir/tigress_scores.sf; fi

#Pruning noise from the network, dropping edges bellow a specific P-value (1.28 or 0.10% by default)
#If the desired P-value is 0.05% the -p should be 1.64, and for 0.01% the -p should be 2.32
seidr backbone -F $pvalue $BASE_DIR/$outdir/network.sf

#-----------------------------------------  FALTA POSTPROCESSING : FALAR C O PEDRO ---------------------------------------

#-------------------------------------------------- END OF MAIN CODE -----------------------------------------------------

# Function to set default values for optional parameters
set_default_values() {
  # Set default values if variables are not set
  [[ -z $rawcountsfile || -z $thread ]] && {
    printf "\n---------------------\n -- ERROR: options -f and -n are required!-- \n--------------------\n\n"
    usage
    exit 1
  }

  # Default aggregation method
  aggregate="${aggregate:-irp}"
  printf " | Using the aggregation method: $aggregate\n"

  # Default output directory
  outdir="${outdir:-seidr_output}"
  printf " | Outputting the files to the Out-Directory = $outdir\n"

  # Default p-value
  pvalue="${pvalue:-0.10}"
  printf " | Applying p-value for pruning noise: $pvalue\n"

  # Default depth setting
  depth="${depth:-SLOW}"
  printf " | Applying computational speed: $depth\n"

  # Default target setting
  target="${target:-FALSE}"
  printf " | Targeted network: $target\n"

  # Default cutoff setting
  cutoff="${cutoff:-None}"
  printf " | Applying cutoff: $cutoff\n"

  # Default stats setting
  stats="${stats:-TRUE}"
  if [[ "$stats" != "TRUE" && "$stats" != "FALSE" ]]; then
    printf " | ERROR: Invalid value for -s/--stats. Acceptable values are 'TRUE' or 'FALSE'. Using default: TRUE.\n"
    stats="TRUE"  # Default to TRUE if invalid value
  fi
  printf " | Calculate network and node statistics: $stats\n"

  # Default edge correlation scores
  edgecorscores="${edgecorscores:-TRUE}"
  if [[ "$edgecorscores" != "TRUE" && "$edgecorscores" != "FALSE" ]]; then
    printf " | ERROR: Invalid value for -e/--edgecorscores. Acceptable values are 'TRUE' or 'FALSE'. Using default: TRUE.\n"
    edgecorscores="TRUE"  # Default to TRUE if invalid value
  fi
  printf " | Generate edge correlation scores: $edgecorscores\n"
}