#!/usr/bin/Rscript
print("O SCRIPT R ESTA A CORRER")

options(repos = c(CRAN = "https://cloud.r-project.org"))

install.packages("argparse")
install.packages("RColorBrewer")
install.packages("BiocManager")
BiocManager::install()
BiocManager::install("DESeq2")