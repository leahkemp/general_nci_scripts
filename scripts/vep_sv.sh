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
#    Annotate SV VCF file with VEP on NCI

#    Assumptions:
#    * hg38
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)
#    * access to if89 project where installations are hosted
#    * access to xy86 project where variant databases are hosted

# define functions
# usage
usage() {
    echo
    echo "Usage:"
    echo "    qsub -v IN_VCF=LRS00189-01-PB-01.hg38.sniffles.sv.phased.vcf.gz,REF=/g/data/kr68/genome/hg38.analysisSet.fa ./vep_sv.sh"
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
    echo "[VEP SV: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[VEP SV: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# define default params
: "${OUT_DIR:=./}"

# set vars
VEP_DB="/g/data/if89/datalib/vep/112/grch38/"
CADD_SV_DB="/g/data/xy86/cadd_sv/1.1/grch38/1000G_phase3_SVs.tsv.gz"

# user input checks
[ -z "${IN_VCF}" ] && usage
[ -z "${OUT_DIR}" ] && usage
test -e "${IN_VCF}" || die "Error: in VCF file '${IN_VCF}' doesn't exist."
test -e "${VEP_DB}" || die "Error: database '${VEP_DB}' doesn't exist."
test -e "${CADD_SV_DB}" || die "Error: database '${CADD_SV_DB}' doesn't exist."
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
vep -i ${IN_VCF} -o ${OUT_DIR}/${FILENAME}.annotated.vcf.gz --format vcf --vcf --fasta ${REF} --dir ${VEP_DB} --assembly GRCh38 --species homo_sapiens --cache --offline --merged --sift b --polyphen b --symbol --hgvs --hgvsg --uploaded_allele --check_existing --filter_common --distance 0 --nearest gene --canonical --mane --pick --fork ${PBS_NCPUS} --no_stats --compress_output bgzip --dont_skip
--plugin CADD,sv=${CADD_SV_DB} || die "Error: issue annotating VCF with VEP."

# index VCF
log "Indexing VCF."
tabix ${OUT_DIR}/${FILENAME}.annotated.vcf.gz || die "Error: issue indexing output VCF."

log "Complete!"

