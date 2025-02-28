#!/bin/bash


# This script is for transposon analysis of vancomycin resistant enterococci
# This script is designed for genomes assembled with SKESA. All genome files must be in fasta format with a name following the pattern: SAMPLEIDENTIFIER.fasta
# Requires a list of samples, in the job directory 
# Requires all genomes to be in a folder named 'genomes_skesa' in root directory
# Requires reference genomes M97297_VanA.fasta and VanB_Tn1549_transposon_complete.fasta to be in folder 'ref_sequences' in root directory
# Requires the file 'transposon_typing_AUMC.py' to be in a folder 'genecollector' in the root directory
# Conda dependencies: gawk, abricate, python3 and blast

#######
# Usage
#######
# cd /home/[user]/vre/genecollector
# command : bash [this_script].sh [job directory] [list of samples in the job directory]
# ex: bash GeneCollector_script_JHI.sh 20220101 outbreak_samples_list_20220101.txt

# Root directory, check if this is correct
SPTH='/home/[user]/vre'

# name of the job directory
job_dir=$1

# Name of the file containing the sample identifiers
smpl_list=$2

# Job directory, change name of job, every job should have a unique name
JBD=${SPTH}/genecollector/${job_dir}

# List of samples, comtain only the list of sample identifiers (TY numbers), every number on a new row
SPFL=${JBD}/${smpl_list}


# Create directories 
mkdir -p ${JBD}/abricate
mkdir -p ${JBD}/genecollector
mkdir -p ${JBD}/genomes_skesa_job
mkdir -p ${JBD}/blast

echo "Job started at" $(date)

#############
# Copy genomes from other path to new file. First add path and filename to file with TY numbers. Then copy these files into new folder
############

# for first time use, change path to your genomes_skesa folder
awk '{print "/home/[user]/vre/genomes_skesa/"$0"_skesa.fasta"}' ${SPFL} > ${JBD}/output_files.txt
for  file in $(<${JBD}/output_files.txt); do cp "$file" ${JBD}/genomes_skesa_job; done

############
# Abricate for all genomes in folder 
############

echo "Start Abricate"

abricate ${JBD}/genomes_skesa_job/*_skesa.fasta >  ${JBD}/abricate/Abricate_out.txt

############
# Move genecollector to right folder and run it
############

echo "Start genecollector"

cp /home/[user]/vre/genecollector/genecollector_Seb.py ${JBD}/genecollector/transposon_typing_AUMC.py
cd ${JBD}/genecollector/
python3 transposon_typing_AUMC.py
cd ..

############
# Use Blast to remove sequence outside of transposon. First make database of your contigs and then blast a reference and only keep the results. Transform to fasta format
# If you want to change the reference which determines the size of the final sequences, do it here. 
############

echo "Start Blast"
makeblastdb -in ${JBD}/genecollector/VRE_contigs.fasta -out ${JBD}/blast/VRE_contigs_DB -dbtype nucl
blastn -db ${JBD}/blast/VRE_contigs_DB -query ${SPTH}/genecollector/ref_sequences/M97297_VanA.fasta -out ${JBD}/VRE_transposon_VanA.txt -outfmt "6 sseqid sseq" 
blastn -db ${JBD}/blast/VRE_contigs_DB -query ${SPTH}/genecollector/ref_sequences/VanB_Tn1549_transposon_complete.fasta -out ${JBD}/VRE_transposon_VanB.txt -outfmt "6 sseqid sseq" 

awk '{print ">"$1"\n"$2}' ${JBD}/VRE_transposon_VanA.txt > ${JBD}/VRE_transposon_VanA.fasta
awk '{print ">"$1"\n"$2}' ${JBD}/VRE_transposon_VanB.txt > ${JBD}/VRE_transposon_VanB.fasta

# If you want to change the reference which is added for alignment, do it here. 
# If you want to change the fasta header (for example add ST type), do it here. 
cat ${SPTH}/genecollector/ref_sequences/vanA_operon_PJEV01000003.fasta >> ${JBD}/VRE_transposon_VanA.fasta
cat ${SPTH}/genecollector/ref_sequences/VanB_operon.fasta >> ${JBD}/VRE_transposon_VanB.fasta


############
# If transposon sequences are cut into different short sequences, this is a result from blast. then align the contigs as 
# a whole, without manipulation by blast and align them with MAFFT
############

#for back-up, if you want to align the contigs as a whole
cp ${JBD}/genecollector/VRE_contigs.fasta ${JBD}/VRE_contigs_VanA.fasta

cat ${SPTH}/genecollector/ref_sequences/vanA_operon_PJEV01000003.fasta >> ${JBD}/VRE_contigs_VanA.fasta
cat ${SPTH}/genecollector/ref_sequences/M97297_VanA.fasta >> ${JBD}/VRE_contigs_VanA.fasta

cp ${JBD}/genecollector/VRE_contigs.fasta ${JBD}/VRE_contigs_VanB.fasta
cat ${SPTH}/genecollector/ref_sequences/VanB_operon.fasta >> ${JBD}/VRE_contigs_VanB.fasta 
cat ${SPTH}/genecollector/ref_sequences/VanB_Tn1549_transposon_complete.fasta >> ${JBD}/VRE_contigs_VanB.fasta
