#!/bin/bash

#PBS -P kr68
#PBS -l storage=gdata/kr68+scratch/kr68+gdata/ox63
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
#    md5sum file on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)

# define functions
# usage
usage() {
    echo
    echo "Usage:"
    echo "    qsub -v IN_FILE=DM_1_QGXXXX250341.fastq.gz ./md5sum.sh"
    echo "Optional parameters:"
    echo "    OUT_DIR=/output/directory"
    echo
    exit 1
}

# terminate
die() {
    echo "[md5sum: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[md5sum: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# define default params
: "${OUT_DIR:=./}"

# user input checks
[ -z "${IN_FILE}" ] && usage
test -e "${IN_FILE}" || die "Error: in file '${IN_FILE}' doesn't exist."

# set vars
FILENAME=$(basename ${IN_FILE})

# check output directory is writable
mkdir -p ${OUT_DIR}
[ ! -w "${OUT_DIR}" ] && die "Error: output directory '${OUT_DIR}' is not writable."

log "Calculating md5sum."
md5sum ${IN_FILE} >> ${OUT_DIR}/${FILENAME}.md5 || die "Error: issue calculating md5sum."

log "Complete!"

