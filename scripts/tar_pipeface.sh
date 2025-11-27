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
#    tar and md5sum a pipeface output directory ready to send

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)

# define functions
# usage
usage() {
    echo "Usage:"
    echo "Singleton:"
    echo "    qsub -v ID=LRS00473-00-ON-01,DIR=/g/data/kr68/projects/KISKUM_Dystonia/LRS00473/pipeface-v0.9.4/20251107-173122/LRS00473-00-ON-01/ ./tar_pipeface.sh" >&2
    echo "Duo/Trio:"
    echo "    qsub -v ID=LRS00429,DIR=/g/data/kr68/projects/KISKUM_Dystonia/LRS00429/pipeface-v0.9.4/20251124-103547/ ./tar_pipeface.sh" >&2
    echo "Optional parameters:"
    echo "    OUT_DIR=/output/directory"
    echo
    exit 1
}

# terminate
die() {
    echo "[Tar pipeface: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[Tar pipeface: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# define default params
: "${OUT_DIR:=./}"

# user input checks
[ -z "${ID}" ] && usage
[ -z "${DIR}" ] && usage
[ -z "${OUT_DIR}" ] && usage
test -e "${DIR}" || die "Error: '${DIR}' directory doesn't exist."
# check output directory is writable
mkdir -p ${OUT_DIR}
[ ! -w "${OUT_DIR}" ] && die "Error: output directory '${OUT_DIR}' is not writable."

# tar and md5sum
log "Tarring ${DIR}."
tar -C ${DIR} -cvf ${OUT_DIR}/${ID}.tar . || die "Error: issue tarring ${DIR}."
log "Md5summing ${OUT_DIR}/${ID}.tar."
md5sum ${OUT_DIR}/${ID}.tar > ${ID}.tar.md5 || die "Error: issue md5summing tarball."

log "Complete!"
