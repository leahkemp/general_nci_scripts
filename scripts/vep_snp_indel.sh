#!/bin/bash

#PBS -P kr68
#PBS -l storage=gdata/kr68+scratch/kr68+gdata/if89+gdata/xy86
#PBS -q normal
#PBS -l ncpus=32
#PBS -l mem=128gb
#PBS -l walltime=24:00:00
#PBS -l wd

#    Author:
#    Leah Kemp
#    Genomic Technologies Group
#    Garvan Institute Medical Research

#    Script Description:
#    Annotate SNP/indel VCF file with VEP on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)
#    * access to if89 project where installations are hosted
#    * access to xy86 project where variant databases are hosted

# define functions
# usage
usage() {
    echo
    echo "Usage:"
    echo "    qsub -v IN_VCF=LRS00189-01-PB-01.hg38.clair3.snp_indel.phased.vcf.gz,REF=/g/data/kr68/genome/hg38.analysisSet.fa ./vep_snp_indel.sh"
    echo "Optional parameters:"
    echo "    OUT_DIR=/output/directory"
    echo ""
    echo "Information:"
    echo "    Use the reference genome used to generate the VCF"
    echo
    exit 1
}

# terminate
die() {
    echo "[VEP SNP/indel: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[VEP SNP/indel: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# define default params
: "${OUT_DIR:=./}"

# set vars
VEP_DB="/g/data/if89/datalib/vep/112/grch38/"
REVEL_DB="/g/data/xy86/revel/1.3/grch38/new_tabbed_revel_grch38.tsv.gz"
GNOMAD_DB="/g/data/xy86/gnomad/genomes/v4.1.0/gnomad.joint.v4.1.sites.chrall.vcf.gz"
CLINVAR_DB="/g/data/xy86/clinvar/2024-08-25/grch38/clinvar_20240825.vcf.gz"
CADD_SNV_DB="/g/data/xy86/cadd/1.7/grch38/whole_genome_SNVs.tsv.gz"
CADD_INDEL_DB="/g/data/xy86/cadd/1.7/grch38/gnomad.genomes.r4.0.indel.tsv.gz"
SPLICEAI_SNV_DB="/g/data/xy86/spliceai/v1.3/grch38/spliceai_scores.raw.snv.hg38.vcf.gz"
SPLICEAI_INDEL_DB="/g/data/xy86/spliceai/v1.3/grch38/spliceai_scores.raw.indel.hg38.vcf.gz"
ALPHAMISSENSE_DB="/g/data/xy86/alphamissense/grch38/AlphaMissense_hg38.tsv.gz"

# user input checks
[ -z "${IN_VCF}" ] && usage
[ -z "${OUT_DIR}" ] && usage
test -e "${IN_VCF}" || die "Error: in VCF file '${IN_VCF}' doesn't exist."
test -e "${VEP_DB}" || die "Error: database '${VEP_DB}' doesn't exist."
test -e "${REVEL_DB}" || die "Error: database '${REVEL_DB}' doesn't exist."
test -e "${GNOMAD_DB}" || die "Error: database '${GNOMAD_DB}' doesn't exist."
test -e "${CLINVAR_DB}" || die "Error: database '${CLINVAR_DB}' doesn't exist."
test -e "${CADD_SNV_DB}" || die "Error: database '${CADD_SNV_DB}' doesn't exist."
test -e "${CADD_INDEL_DB}" || die "Error: database '${CADD_INDEL_DB}' doesn't exist."
test -e "${SPLICEAI_SNV_DB}" || die "Error: database '${SPLICEAI_SNV_DB}' doesn't exist."
test -e "${SPLICEAI_INDEL_DB}" || die "Error: database '${SPLICEAI_INDEL_DB}' doesn't exist."
test -e "${ALPHAMISSENSE_DB}" || die "Error: database '${ALPHAMISSENSE_DB}' doesn't exist."
FILENAME=$(basename ${IN_VCF} | sed 's/.vcf.*//')
! test -e "${OUT_DIR}/${FILENAME}.annotated.vcf.gz" || die "Error: output file '${OUT_DIR}/${FILENAME}.annotated.vcf.gz' already exists."
# check output directory is writable
mkdir -p ${OUT_DIR}
[ ! -w "${OUT_DIR}" ] && die "Error: output directory '${OUT_DIR}' is not writable."

# load modules
module use -a /g/data/if89/apps/modulefiles
module use -a /g/data/if89/shpcroot/modules
module load singularity
module load htslib/1.20
module load ensemblorg/ensembl-vep/release_112.0

# run VEP
log "Running VEP."
vep -i ${IN_VCF} -o ${OUT_DIR}/${FILENAME}.annotated.vcf.gz --format vcf --vcf --fasta ${REF} --dir ${VEP_DB} --assembly GRCh38 --species homo_sapiens --cache --offline --merged --sift b --polyphen b --symbol --hgvs --hgvsg --uploaded_allele --check_existing --filter_common --distance 0 --nearest gene --canonical --mane --pick --fork ${PBS_NCPUS} --no_stats --compress_output bgzip --dont_skip \
--plugin REVEL,file=${REVEL_DB} --custom file=${GNOMAD_DB},short_name=gnomAD,format=vcf,type=exact,fields=AF_joint%AF_exomes%AF_genomes%nhomalt_joint%nhomalt_exomes%nhomalt_genomes \
--custom file=${CLINVAR_DB},short_name=ClinVar,format=vcf,type=exact,coords=0,fields=CLNSIG \
--plugin CADD,snv=${CADD_SNV_DB},indels=${CADD_INDEL_DB} \
--plugin SpliceAI,snv=${SPLICEAI_SNV_DB},indel=${SPLICEAI_INDEL_DB} \
--plugin AlphaMissense,file=${ALPHAMISSENSE_DB} || die "Error: issue annotating VCF with VEP."

# index VCF
log "Indexing VCF."
tabix ${OUT_DIR}/${FILENAME}.annotated.vcf.gz || die "Error: issue indexing output VCF."

log "Complete!"

