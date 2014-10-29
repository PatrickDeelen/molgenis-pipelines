#MOLGENIS walltime=240:00:00 nodes=1 cores=10 mem=20



mergedVcfFile=${mergedVcfFile}
GoNL=${GoNL}
BeagleJar=${BeagleJar}
prepareForBeagleJar=${prepareForBeagleJar}
chr=${chr}
chunk=${chunk}
imputedVcfChunkPrefix=${imputedVcfChunkPrefix}
imputedVcfChr=${imputedVcfChr}

<#noparse>

hostname

module load jdk

localOutput=${TMPDIR}/
localImputedPrefix=${localOutput}chr${chr}.chunk${chunk}.imputed
exclMarkersFile=${localOutput}chr${chr}.chunk${chunk}.ExcludeRefMarkers.txt

echo "chr=${chr}"
echo "chunk=${chunk}"
echo "mergedVcfFile=${mergedVcfFile}"
echo "localImputedPrefix=${localImputedPrefix}"
echo "imputedVcfChr=${imputedVcfChr}"
echo "imputedVcfChunkPrefix=${imputedVcfChunkPrefix}"
echo "exclMarkersFile=${exclMarkersFile}"


if [ -s ${imputedVcfChr} ]; then
	echo "File exists: ${imputedVcfChr}"
	echo "skipping chr${chr}"
elif [ -s "${imputedVcfChunkPrefix}.vcf.gz" ]; then
	echo "File exists: ${imputedVcfChunkPrefix}.vcf.gz"
	echo "skipping chr${chr} chunk${chunk}"
else
	echo "Processing chr${chr} chunk${chunk}"
	
	localMergedVcfFile=${localOutput}/chr${chr}.vcf.gz
	cp ${mergedVcfFile} ${localMergedVcfFile}
	
	echo "Copied the VCF file to ${localMergedVcfFile}"
	
	echo "Preparing VCFs for Beagle"
	#
	# Detect regions without SNPs in the data to be imputed
	#
	
	java \
	-Xmx20g \
	-Xms20g \
	-jar ${prepareForBeagleJar} \
		--chunkSize 24000 \
		--excludedMarkers ${exclMarkersFile} \
		--refVariants ${GoNL}/chr${chr}.${chunk}.txt \
		--studyVcf ${localMergedVcfFile} \
		--outputVcf $localOutput/tmp.vcf
	rm ${localOutput}/tmp.vcf
	
	prepareReturnCode=$?
	echo "prepareReturnCode return code: $prepareReturnCode"
	
	if [ ! $prepareReturnCode -eq 0 ]; then
		echo "Prepare for Beagle failed, not making files final"
		exit 1
	fi

	#
	# Impute
	#
	
	echo "Imputation"
	
	java \
	-Djava.io.tmpdir=$TMPDIR \
	-Xmx20g \
	-Xms20g \
	-jar ${BeagleJar} \
	nthreads=10 \
	gl=${localMergedVcfFile} \
	ref=${GoNL}chr${chr}.${chunk}.vcf.gz \
	chrom=${chr} \
	excludemarkers=${exclMarkersFile} \
	out=${localImputedPrefix}
	
	returnCode=$?
	echo "Beagle return code: $returnCode"
	if [ $returnCode -eq 0 ]; then
		echo "Moving temp files: ${localImputedPrefix}* to ${imputedVcfChunkPrefix}*"
		mv -v ${localImputedPrefix}.vcf.gz ${imputedVcfChunkPrefix}.vcf.gz
		mv -v ${localImputedPrefix}.log ${imputedVcfChunkPrefix}.log
	else
		echo "Beagle failed, not making files final"
		exit 1
	fi
fi

</#noparse>