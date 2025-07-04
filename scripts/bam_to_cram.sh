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
#    Convert BAM to CRAM on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage/project charged as appropriate)
#    * access to if89 project where installations are hosted

set -eo pipefail

# define functions
# usage
usage() {
    echo
    echo "Usage: qsub -v BAM=./HG00155.hg38.minimap2.whatshap.sorted.haplotagged.bam,REF=/g/data/kr68/genome/hg38.analysisSet.fa ./bam_to_cram.sh" >&2
    echo
    exit 1
}

# terminate
die() {
    echo "[BAM to CRAM: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[BAM to CRAM: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# user input checks
[ -z "${BAM}" ] && usage
[ -z "${REF}" ] && usage
test -e "${BAM}" || die "Error: '${BAM}' file doesn't exist."
test -e "${REF}" || die "Error: '${REF}' file doesn't exist."

# load modules
module use -a /g/data/if89/apps/modulefiles
module load samtools/1.21

# get dir and filenames
DIR=$(dirname ${BAM}) || die "Error: issue getting directory."
FILENAME=$(basename ${BAM} | sed 's/.bam//')  || die "Error: issue getting filename."

# check if output files already exists
[ -f ${DIR}/${FILENAME}.cram ] && die "Error: output file already exists at '${DIR}/${FILENAME}.cram'."
[ -f ${DIR}/${FILENAME}.cram.crai ] && die "Error: output file index already exists at '${DIR}/${FILENAME}.cram.crai'."

# run conversion
log "Running BAM to CRAM conversion"
samtools view -@ ${PBS_NCPUS} -T ${REF} -C -o ${DIR}/${FILENAME}.cram ${BAM} --write-index || die "Error: issue converting BAM to CRAM."

log "Complete!"

