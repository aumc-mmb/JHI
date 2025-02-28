################
#Instructions
################

# This template must be modified so that the path variable ${SPTH} matches with the user's home folder.
# Raw Illumina paired-end reads must be placed in a folder called: ${SPTH}/raw_reads.
# A list of samples must be provided in text form: it should only be the file name, without any file extension.
# bash [this file] [list of sample identifiers.txt]

list_fasta_samples=$1
[[ -z "$1" ]] && { echo "Parameter 1 is empty" ; exit 1; }


SPTH='/home/[user]/vre'

mkdir -p ${SPTH}/genomes_skesa
mkdir -p ${SPTH}/fastqc_output_trim_reads_skesa
mkdir -p ${SPTH}/genome_coverage
mkdir -p ${SPTH}/abricate_out

while read seqID
do
####################
# Trimmomatic and adapter removal
####################

trimmomatic PE ${SPTH}/raw_reads/${seqID}1.fastq.gz ${SPTH}/raw_reads/${seqID}2.fastq.gz ${SPTH}/raw_reads/${seqID}1_trim.fastq.gz ${SPTH}/raw_reads/${seqID}1_untrim.fastq.gz ${SPTH}/raw_reads/${seqID}2_trim.fastq.gz ${SPTH}/raw_reads/${seqID}2_untrim.fastq.gz ILLUMINACLIP:${SPTH}/trimmomatic/TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:15 LEADING:3 TRAILING:3 MINLEN:36

echo "Trimming complete at" $(date)

##################
# FastQC
##################
fastqc ${SPTH}/raw_reads/${seqID}1_trim.fastq.gz -o ${SPTH}/fastqc_output_trim_reads_skesa
fastqc ${SPTH}/raw_reads/${seqID}2_trim.fastq.gz -o ${SPTH}/fastqc_output_trim_reads_skesa

echo "Fastqc complete at" $(date)

#################
# Genome assembly with SKESA
#################
skesa --fastq ${SPTH}/raw_reads/${seqID}1_trim.fastq.gz,${SPTH}/raw_reads/${seqID}2_trim.fastq.gz --gz --cores 15 --memory 60 --min_contig 1000 > ${SPTH}/genomes_skesa/${seqID}.fasta

wait

echo "SKESA complete at" $(date)

####################
# Re-assembly with minimap2
####################

minimap2 -a -x sr -t 16 ${SPTH}/genomes_skesa/${seqID}.fasta ${SPTH}/raw_reads/${seqID}1_trim.fastq.gz ${SPTH}/raw_reads/${seqID}2_trim.fastq.gz > ${SPTH}/raw_reads/${seqID}.bam

####################
# Sort BAM file with Samtools
####################

samtools sort -l 0 --threads 16 ${SPTH}/raw_reads/${seqID}.bam -o ${SPTH}/raw_reads/${seqID}_sorted.bam

####################
# Assess genome coverage with Bedtools
####################

bedtools genomecov -d -ibam ${SPTH}/raw_reads/${seqID}_sorted.bam > ${SPTH}/raw_reads/${seqID}_depth_all_positions.txt

####################
# Count average value with awk
####################

cat ${SPTH}/raw_reads/${seqID}_depth_all_positions.txt | awk '{t += $3} END {print t/NR}' > ${SPTH}/genome_coverage/${seqID}_coverage_depth_average.txt

####################
# Find resistance genes with Abricate
####################

abricate ${SPTH}/genomes_skesa/${seqID}.fasta > ${SPTH}/abricate_out/${seqID}_abricate_out.txt
done < ${list_fasta_samples}