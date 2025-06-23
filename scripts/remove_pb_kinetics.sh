#!/bin/bash

#PBS -P kr68
#PBS -l storage=scratch/kr68+gdata/kr68
#PBS -q normal
#PBS -l ncpus=4
#PBS -l mem=16gb
#PBS -l walltime=3:00:00
#PBS -l wd

#    Author:
#    Ira Deveson and Leah Kemp
#    Genomic Technologies Group
#    Garvan Institute Medical Research

#    Script Description:
#    Remove kinetics data from a pacbio uBAM on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)
#    * input file is a pacbio uBAM contining kinetic data

# define functions
# usage
usage() {
    echo "Usage: qsub -v BAM=./RGBX240282/84088_240923_035552_s1.hifi_reads.bc2005.bam ./remove_pb_kinetics.sh" >&2
    echo
    exit 1
}

# terminate
die() {
    echo "[Remove pacbio kinetics: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# user input checks
[ -z "${BAM}" ] && usage
test -e ${BAM} || die "Error: '${BAM}' file doesn't exist"

# get filepath without '.bam' suffix
FILE_PATH=$(echo ${BAM} | sed 's/.bam//')

# load samtools module
module load samtools/1.19

# remove kinetic data
samtools view -@ ${PBS_NCPUS} --remove-tag=fi,fn,fp,ri,rn,rp -b ${BAM} -o ${FILE_PATH}.no_kinetics.bam

