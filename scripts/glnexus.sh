#!/bin/bash

#PBS -P kr68
#PBS -l storage=gdata/kr68+scratch/kr68+gdata/if89
#PBS -q normal
#PBS -l ncpus=43
#PBS -l mem=190gb
#PBS -l walltime=06:00:00
#PBS -l wd

#    Author:
#    Leah Kemp
#    Genomic Technologies Group
#    Garvan Institute Medical Research

#    Script Description:
#    Merge multiple Clair3 or DeepVariant SNP/indel GVCF's into a joint call VCF with GLnexus on NCI

#    Assumptions:
#    * access to kr68 project (or the user modifies the PBS storage as appropriate)
#    * access to if89 project where installations are hosted
#    * clair3 or deepvariant GVCF files are provided
#    * all GVCF files to be merged are from the same SNP/indel calling software
#    * all GVCF files to be merged are called against the same reference genome

# define functions
# usage
usage() {
    echo
    echo "Usage:"
    echo "Clair3:"
    echo "    qsub -v IN_GVCFS=./in_gvcfs.txt,SNP_INDEL_CALLER=clair3,PREFIX=LRS00061,REF_INDEX=/g/data/kr68/genome/hg38.analysisSet.fa.fai ./glnexus.sh"
    echo "DeepVariant:"
    echo "    qsub -v IN_GVCFS=./in_gvcfs.txt,SNP_INDEL_CALLER=deepvariant,PREFIX=LRS00061 ./glnexus.sh"
    echo "Optional parameters:"
    echo "    OUT_DIR=/output/directory"
    echo "    GVCFS_AMMENDED=TRUE"
    echo "    CLAIR3_GLNEXUS_CONFIG=/g/data/kr68/genome/glnexus_clair3_config.yml"
    echo ""
    echo "Information:"
    echo "    Define the SNP/indel caller used to generate the GVCF's"
    echo "    PREFIX is used to label the output filename. Eg. LRS00061.snp_indel.vcf.gz"
    echo "    Use the reference genome index used to generate the GVCF's"
    echo "    Running GLnexus on clair3 GVCF's requires ammending the GVCF's before merging. Set GVCFS_AMMENDED=TRUE to pass a list of already ammended GVCF's to IN_GVCFS."
    echo
    exit 1
}

# terminate
die() {
    echo "[GLnexus: $(date +'%Y-%m-%d %H:%M:%S')]" "$1" >&2
    exit 1
}

# logging
log() {
    echo "[GLnexus: $(date +'%Y-%m-%d %H:%M:%S')]" "$@"
}

# define default params
: "${OUT_DIR:=./}"
: "${GVCFS_AMMENDED:=FALSE}"
: "${CLAIR3_GLNEXUS_CONFIG:=/g/data/kr68/genome/glnexus_clair3_config.yml}"

# user input checks
[ -z "${IN_GVCFS}" ] && usage
[ -z "${SNP_INDEL_CALLER}" ] && usage
[ -z "${PREFIX}" ] && usage
[ -z "${OUT_DIR}" ] && usage
if ! [[ "${SNP_INDEL_CALLER}" =~ ^(clair3|deepvariant)$ ]]; then
    die "Error: SNP/indel caller should be either 'clair3' or 'deepvariant', '${SNP_INDEL_CALLER}' provided.";
fi
test -e "${IN_GVCFS}" || die "Error: in GVCF's file '${IN_GVCFS}' doesn't exist."
! test -e "${OUT_DIR}/${PREFIX}.snp_indel.vcf.gz" || die "Error: output file '${OUT_DIR}/${PREFIX}.snp_indel.vcf.gz' already exists."
while IFS= read -r FILE; do
    if [ ! -e "${FILE}" ]; then
        die "Error: GVCF file '${FILE}' defined in '${IN_GVCFS} doesn't exist."
    fi
done < ${IN_GVCFS}
# check output directory is writable
mkdir -p ${OUT_DIR}
[ ! -w "${OUT_DIR}" ] && die "Error: output directory '${OUT_DIR}' is not writable."

# set vars
DATE=$(date +"%Y%m%d-%H%M%S")
WORK="glnexus_work_${PREFIX}_${DATE}"

# load modules
module use -a /g/data/if89/apps/modulefiles
module load glnexus/1.4.3
module load bcftools/1.21
module load htslib/1.20

if [[ "${SNP_INDEL_CALLER}" == "clair3" ]]; then
    # user input checks
    test -e "${CLAIR3_GLNEXUS_CONFIG}" || die "Error: clair3 glnexus config file '${CLAIR3_GLNEXUS_CONFIG}' doesn't exist. Define the location of this file with the CLAIR3_GLNEXUS_CONFIG parameter."
    if [[ "${GVCFS_AMMENDED}" == "FALSE" ]]; then
        # user input checks
        [ -z "${REF_INDEX}" ] && usage
        test -e "${REF_INDEX}" || die "Error: reference index file '${REF_INDEX}' doesn't exist."
        # pre-process gvcf files
        # reheader to include all contigs in gvcf header even if no variants were called in the contig
        # to avoid this issue: https://github.com/HKU-BAL/Clair3/issues/371
        # also convert lower cases of soft-masked sequences to upper case
        # to avoid this issue: https://github.com/HKU-BAL/Clair3/issues/359
        log "Pre-processing GVCF's."
        AMMENDED_GVCFS="ammended_gvcfs_${PREFIX}_${DATE}"
        mkdir -p ${AMMENDED_GVCFS}
        CONTIG=($(cut -f1 ${REF_INDEX}))
        LENGTH=($(cut -f2 ${REF_INDEX}))
        for i in ${!CONTIG[@]}; do printf "##contig=<ID=${CONTIG[i]},length=${LENGTH[i]}>\n" >> ${AMMENDED_GVCFS}/header_contigs.txt; done
        export AMMENDED_GVCFS
        cat ${IN_GVCFS} | xargs -P ${PBS_NCPUS} -I{} bash -c '
            FILE="{}"
            DIR=$(dirname ${FILE})
            FILENAME=$(basename ${FILE} | sed "s/.g.vcf.gz//")
            cd ${AMMENDED_GVCFS}
            zcat ${FILE} | head -n1000 | grep "#" > ${FILENAME}.header.txt
            grep -v -E "##contig=|#CHROM" ${FILENAME}.header.txt > ${FILENAME}.ammended.g.vcf
            cat header_contigs.txt >> ${FILENAME}.ammended.g.vcf
            grep "#CHROM" ${FILENAME}.header.txt >> ${FILENAME}.ammended.g.vcf
            zgrep -v "#" ${FILE} >> ${FILENAME}.ammended.g.vcf
            awk -F"\t" -v OFS="\t" '"'"'/^[^#]/{$4=toupper($4)} {$5=toupper($5)} {print $0}'"'"' ${FILENAME}.ammended.g.vcf | bgzip > ${FILENAME}.ammended.g.vcf.gz
            rm ${FILENAME}.header.txt
            rm ${FILENAME}.ammended.g.vcf
        ' || die "Error: issue pre-processing GVCF files before merge with GLnexus."
        # cleanup
        rm ${AMMENDED_GVCFS}/header_contigs.txt
        # get new list of files
        realpath ${AMMENDED_GVCFS}/*.ammended.g.vcf.gz > ${AMMENDED_GVCFS}/files_ammended.txt
        IN_GVCFS=$(realpath ${AMMENDED_GVCFS}/files_ammended.txt)
    fi
    # run glnexus
    log "Running GLnexus."
    glnexus_cli --config ${CLAIR3_GLNEXUS_CONFIG} --list ${IN_GVCFS} --dir ${WORK} > ${OUT_DIR}/${PREFIX}.snp_indel.bcf || die "Error: issue merging GVCF files with GLnexus."
elif [[ "${SNP_INDEL_CALLER}" == "deepvariant" ]]; then
    # run glnexus
    log "Running GLnexus."
    glnexus_cli --config DeepVariant --list ${IN_GVCFS} --dir ${WORK}/ > ${OUT_DIR}/${PREFIX}.snp_indel.bcf || die "Error: issue merging GVCF files with GLnexus."
fi

# compress and index vcf
log "Compressing and indexing VCF."
bcftools view ${OUT_DIR}/${PREFIX}.snp_indel.bcf | bgzip -@ ${PBS_NCPUS} -c > ${OUT_DIR}/${PREFIX}.snp_indel.vcf.gz || die "Error: issue compressing output VCF."
tabix ${OUT_DIR}/${PREFIX}.snp_indel.vcf.gz || die "Error: issue indexing output VCF."

# cleanup
rm ${OUT_DIR}/${PREFIX}.snp_indel.bcf

log "Complete!"

