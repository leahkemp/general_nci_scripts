#!/bin/bash

#PBS -P kr68
#PBS -l storage=gdata/kr68+scratch/kr68+gdata/if89
#PBS -q normal
#PBS -l ncpus=8
#PBS -l mem=64gb
#PBS -l walltime=04:00:00
#PBS -l wd

#    Author:
#    Leah Kemp
#    Genomic Technologies Group
#    Garvan Institute Medical Research

#    Script Description:
#    Convert CRAM to BAM on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage/project charged as appropriate)
#    * access to if89 project where installations are hosted

set -eo pipefail

# define functions
# usage
usage() {
    echo
    echo "Usage: qsub -v CRAM=./HG00155.hg38.minimap2.whatshap.sorted.haplotagged.cram,REF=/g/data/kr68/genome/hg38.analysisSet.fa ./cram_to_bam.sh" >&2
    echo
    exit 1
}

# terminate
die() {
    echo "[CRAM to BAM: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[CRAM to BAM: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# user input checks
[ -z "${CRAM}" ] && usage
[ -z "${REF}" ] && usage
test -e "${CRAM}" || die "Error: '${CRAM}' file doesn't exist."
test -e "${REF}" || die "Error: '${REF}' file doesn't exist."

# load modules
module use -a /g/data/if89/apps/modulefiles
module load samtools/1.21

# get dir and filenames
DIR=$(dirname ${CRAM}) || die "Error: issue getting directory."
FILENAME=$(basename ${CRAM} | sed 's/.cram//')  || die "Error: issue getting filename."

# check if output files already exists
[ -f ${DIR}/${FILENAME}.bam ] && die "Error: output file already exists at '${DIR}/${FILENAME}.bam'."
[ -f ${DIR}/${FILENAME}.bam.bai ] && die "Error: output file index already exists at '${DIR}/${FILENAME}.bam.bai'."

# run conversion
log "Running CRAM to BAM conversion"
samtools view -@ ${PBS_NCPUS} -T ${REF} -b -o ${DIR}/${FILENAME}.bam ${CRAM} 2>${FILENAME}.cram_to_bam.sderror || die "Error: issue converting CRAM to BAM."
samtools index -@ ${PBS_NCPUS} ${DIR}/${FILENAME}.bam

log "Complete!"

