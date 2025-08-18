#!/bin/bash

#PBS -P kr68
#PBS -l storage=gdata/kr68+scratch/kr68+gdata/if89
#PBS -q normal
#PBS -l ncpus=8
#PBS -l mem=32gb
#PBS -l walltime=12:00:00
#PBS -l wd

#    Author:
#    Leah Kemp
#    Genomic Technologies Group
#    Garvan Institute Medical Research

#    Script Description:
#    Merge multiple ONT or pacbio sniffles/cuteSV SV VCF's into a joint call VCF with Jasmine on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)
#    * access to if89 project where installations are hosted
#    * ONT or pacbio sniffles/cuteSV VCF files are provided
#    * all VCF files to be merged are from the same data type (ONT or pacbio)
#    * all VCF files to be merged are from the same SNP/indel calling software (sniffles or cuteSV)
#    * all VCF files to be merged are called against the same reference genome

# define functions
# usage
usage() {
    echo
    echo "Usage:"
    echo "ONT:"
    echo "    qsub -v IN_VCFS=./in_vcfs.txt,IN_BAMS=./in_bams.txt,DATA_TYPE=ont,PREFIX=LRS00061,REF=/g/data/kr68/genome/hg38.analysisSet.fa ./jasmine.sh"
    echo "Pacbio:"
    echo "    qsub -v IN_VCFS=./in_vcfs.txt,IN_BAMS=./in_bams.txt,DATA_TYPE=pacbio,PREFIX=LRS00061,REF=/g/data/kr68/genome/hg38.analysisSet.fa ./jasmine.sh"
    echo "Optional parameters:"
    echo "    OUT_DIR=/output/directory"
    echo ""
    echo "Information:"
    echo "    PREFIX is used to label the output filename. Eg. LRS00061.sv.vcf.gz"
    echo
    exit 1
}

# terminate
die() {
    echo "[Jasmine: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[Jasmine: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# define default params
: "${OUT_DIR:=./}"

# user input checks
[ -z "${IN_VCFS}" ] && usage
[ -z "${IN_BAMS}" ] && usage
[ -z "${DATA_TYPE}" ] && usage
[ -z "${PREFIX}" ] && usage
[ -z "${REF}" ] && usage
[ -z "${OUT_DIR}" ] && usage
if ! [[ "${DATA_TYPE}" =~ ^(ont|pacbio)$ ]]; then
    die "Error: Data type should be either 'ont' or 'pacbio', '${DATA_TYPE}' provided.";
fi
test -e "${IN_VCFS}" || die "Error: in VCF's file '${IN_VCFS}' doesn't exist."
test -e "${IN_BAMS}" || die "Error: in BAM's file '${IN_BAMS}' doesn't exist."
test -e "${REF}" || die "Error: reference genome file '${REF}' doesn't exist."
! test -e "${OUT_DIR}/${PREFIX}.sv.vcf.gz" || die "Error: output file '${OUT_DIR}/${PREFIX}.sv.vcf.gz' already exists."
while IFS= read -r FILE; do
    if [ ! -e "${FILE}" ]; then
        die "Error: VCF file '${FILE}' defined in '${IN_VCFS}' doesn't exist."
    fi
done < ${IN_VCFS}
while IFS= read -r FILE; do
    if [ ! -e "${FILE}" ]; then
        die "Error: BAM file '${FILE}' defined in '${IN_BAMS}' doesn't exist."
    fi
done < ${IN_BAMS}
# check output directory is writable
mkdir -p ${OUT_DIR}
[ ! -w "${OUT_DIR}" ] && die "Error: output directory '${OUT_DIR}' is not writable."

# set vars
DATE=$(date +"%Y%m%d-%H%M%S")
WORK="jasmine_work_${PREFIX}_${DATE}"

# get full paths
IN_VCFS=$(realpath ${IN_VCFS})
IN_BAMS=$(realpath ${IN_BAMS})
REF=$(realpath ${REF})
OUT_DIR=$(realpath ${OUT_DIR})

# load modules
module use -a /g/data/if89/apps/modulefiles
module load jasminesv/1.1.5-r1
module load bcftools/1.21
module load htslib/1.20

# un-compress vcfs
log "Un-compressing VCF's."
mkdir -p ${WORK}
cd ${WORK}
cat ${IN_VCFS} | xargs -P ${PBS_NCPUS} -I{} bash -c '
    FILE="{}"
    FILENAME=$(basename ${FILE} | sed 's/.vcf.*//')
    gunzip -c ${FILE} > ${FILENAME}.vcf
    realpath ${FILENAME}.vcf >> uncompressed_vcfs.txt
' || die "Error: issue un-compressing VCF files before merge with Jasmine."

# conditionally define iris arguments
if [[ "${DATA_TYPE}" == "ont" ]]; then
    IRIS_ARGS="--run_iris iris_args=min_ins_length=20,--rerunracon,--keep_long_variants"
elif [[ "${DATA_TYPE}" == "pacbio" ]]; then
    IRIS_ARGS="--run_iris iris_args=min_ins_length=20,--rerunracon,--keep_long_variants,--pacbio'"
fi

# run jasmine
log "Running jasmine."
jasmine threads=${PBS_NCPUS} out_dir=./ genome_file=${REF} file_list=uncompressed_vcfs.txt bam_list=${IN_BAMS} out_file=${PREFIX}.sv.tmp.vcf min_support=1 --mark_specific spec_reads=7 spec_len=20 --pre_normalize --output_genotypes --clique_merging --dup_to_ins --normalize_type --require_first_sample --default_zero_genotype ${IRIS_ARGS} || die "Error: issue running jasmine."

# fix vcf header (remove prefix to sample names that jasmine adds)
log "Fixing VCF header."
grep '##' ${PREFIX}.sv.tmp.vcf > ${OUT_DIR}/${PREFIX}.sv.vcf
grep '#CHROM' ${PREFIX}.sv.tmp.vcf | sed 's/\t[0-9]_/\t/g' >> ${OUT_DIR}/${PREFIX}.sv.vcf
grep -v '#' ${PREFIX}.sv.tmp.vcf >> ${OUT_DIR}/${PREFIX}.sv.vcf
bcftools sort ${OUT_DIR}/${PREFIX}.sv.vcf -o ${OUT_DIR}/${PREFIX}.sv.vcf

# compress and index vcf
log "Compressing and indexing VCF."
bgzip -@ ${PBS_NCPUS} ${OUT_DIR}/${PREFIX}.sv.vcf || die "Error: issue compressing output VCF."
tabix ${OUT_DIR}/${PREFIX}.sv.vcf.gz || die "Error: issue indexing output VCF."

log "Complete!"

