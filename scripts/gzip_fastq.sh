#!/bin/bash

#PBS -P kr68
#PBS -l storage=gdata/kr68+scratch/kr68
#PBS -q normal
#PBS -l ncpus=1
#PBS -l mem=4gb
#PBS -l walltime=12:00:00
#PBS -l wd

#    Author:
#    Leah Kemp
#    Genomic Technologies Group
#    Garvan Institute Medical Research

#    Script Description:
#    Compress FASTQ file on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)

# define functions
# usage
usage() {
    echo
    echo "Usage:"
    echo "    qsub -v IN_FASTQ=QGXXXX250341.fastq ./gzip_fastq.sh"
    echo "Optional parameters:"
    echo "    OUT_DIR=/output/directory"
    echo
    exit 1
}

# terminate
die() {
    echo "[gzip FASTQ: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[gzip FASTQ: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# define default params
: "${OUT_DIR:=./}"

# user input checks
[ -z "${IN_FASTQ}" ] && usage
test -e "${IN_FASTQ}" || die "Error: in FASTQ file '${IN_FASTQ}' doesn't exist."

# set vars
FILENAME=$(basename ${IN_FASTQ})

# check output directory is writable
mkdir -p ${OUT_DIR}
[ ! -w "${OUT_DIR}" ] && die "Error: output directory '${OUT_DIR}' is not writable."

log "Compressing FASTQ."
gzip ${IN_FASTQ} -c > ${OUT_DIR}/${FILENAME}.gz || die "Error: issue compressing FASTQ file."

log "Complete!"

