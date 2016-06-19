#!/bin/sh
main(){
	sORF_PATH_FOLDER=sORF_analysis

	# create_folders
	# get_genome_files
	# mask_sORF_to_intergenic
	# run_sORFs_input_from_bed
	# blastn_analysis
	# blastn2alignment
	# run_multiple_sequence_alignment
	# run_RNAcode
	# sum_RNAcode_output
	# run_Ribo_calculation
	# cal_small_protein_seq_features
	# extract_neg_sORF_from_trRNA
	# build_phylogeny_tree_for_sORF
	# run_adaptive_selection_for_sORF

	# get_sORF_quanti_ecolification
	# get_high_ribo_sORF

	######Next is machine learning
	# build_training_test_data
	 convert_test_format_to_ml
	##### Before next, a manual-check training (Table S2) set should prepared
 	# build_svm_training_model

	 run_svm_prediction
	 combine_prediction_with_info
	# merge_sORF

	#######Next is post analysis for sPEP analysis
	# blast_clust
	# extract_high_conserved
	# run_blast_nr
	# conservation_heatmap

	# split_sORF_from_predictions
	# run_intergenic_sORF_detection
	# run_full_sORF_detection
	# run_blast_parser
	# get_unmapped_hit
	# get_known_sORFs
	# get_related_genome_files
	# generate_package_to_send
	# compress_files
}

create_folders(){
	for FOLDER in bin ${sORF_PATH_FOLDER}/input ${sORF_PATH_FOLDER}/output ${sORF_PATH_FOLDER}/bin
	do
	if ! [ -d $FOLDER ]
		then
			mkdir -p $FOLDER
		fi
	done
}

get_genome_files(){
	echo "Downloading genome files"

	cat list.txt|while read file
	do
	wget -cP $sORF_PATH_FOLDER/reference_sequences \
		ftp://ftp.ncbi.nih.gov/genomes/archive/old_refseq/Bacteria/${file}/NC*
	rm -rf *Glimmer3
	rm -rf *GeneMark*
	rm -rf *gbs*
	rm -rf *Prodigal*
	done

	#Modify header:
	for FILE in $sORF_PATH_FOLDER/reference_sequences/*.fna
	do
		NEW_FILE_NAME=${FILE//.fna/.fa}
		mv "${FILE}" "${NEW_FILE_NAME}"
		python bin/mod_fasta_head.py "$NEW_FILE_NAME"
	done
	echo "----------------------------------------"
	echo "Content of" $sORF_PATH_FOLDER/reference_sequences

	#Mofidy tab
	#Note: change Ecoli chromosome length to 4641652. the current(20160108) version is still old annotation (U2)
	for FILE in $sORF_PATH_FOLDER/reference_sequences/*.tab
	do
		mv "$FILE" "${FILE}.bk"
		echo -e "$(basename "$FILE.bk")\t$(cut -f4 "${FILE}.bk")"|sed 's/\.tab\.bk//' > "$FILE"
	done
	grep "plasmid" $sORF_PATH_FOLDER/reference_sequences/*.fa|cut -d":" -f1|while read i; do rm -v -rf ${i%.fa}*;done

}

mask_sORF_to_intergenic(){
	mkdir -p $sORF_PATH_FOLDER/output/sORF_mask/
	for file in $sORF_PATH_FOLDER/reference_sequences/NC_011916*.gff
	do
	filename=${file##*/}
	filetag=${filename%.gff}

	# All the larger proteins
	awk '($3=="CDS") || ($3=="rRNA") || ($3=="tRNA")' $file|awk '($5-$4+1)>153'| \
		cut -f4,5,7|while read -r b c d; do \
		echo -e "${filetag}\t$b\t$c\t${b}_$c$d\t0\t$d";done \
		> $sORF_PATH_FOLDER/output/sORF_mask/"${filename%.gff}.bed"

	# All the larger proteins
	#awk '$3>50' "$file" |grep -v "complete"|grep -v "Location"|\
	#	cut -f1|sed 's/\.\./\t/g'|while read -r i j; do \
	#	echo -e "${filetag}\t$i\t$j";done \
	#	> $sORF_PATH_FOLDER/output/sORF_mask/"${filename%.ptt}.bed"

	#known small proteins
	awk '$3=="CDS"' $file|awk '($5-$4+1)<=153'| \
		grep -v "product=hypothetical protein"| \
		cut -f4,5,7|while read -r b c d; do \
		echo -e "${filetag}\t$b\t$c\t${b}_$c$d\t0\t$d";done \
		> $sORF_PATH_FOLDER/output/sORF_mask/"${filename%.gff}_known_sORF.bed"


	#awk '$3<=50 && $5!="-"' "$file" |grep -v "complete"|grep -v "Location"|grep -v "proteins"|\
	#	cut -f1,2|sed 's/\.\./\t/g'|while read -r i j k; do \
	#	echo -e "${filetag}\t$i\t$j\t${i}_${j}${k}\t0\t$k";done \
	#	> $sORF_PATH_FOLDER/output/sORF_mask/"${filename%.ptt}_known_sORF.bed"
	echo "$filename"

	#Make intergenic region
	bedtools complement -i $sORF_PATH_FOLDER/output/sORF_mask/"${filename%.gff}.bed" \
		-g "${file%.gff}.tab" \
		> $sORF_PATH_FOLDER/output/sORF_mask/"${filename%.gff}_intergenic.bed"
	done
}

run_sORFs_input_from_bed(){
	#Prediction of small proteins from bed format files
	mkdir -p $sORF_PATH_FOLDER/output/intergenic_sORF
	for file in $sORF_PATH_FOLDER/reference_sequences/NC_011916*.fa
	do
	filename=${file##*/}
	python3 bin/sORFs_for_bed_input.py \
				-i 40 \
				-min 42 \
				-max 150 \
				-f "$file" \
				-b $sORF_PATH_FOLDER/output/sORF_mask/"${filename%.fa}_intergenic.bed" \
				-on $sORF_PATH_FOLDER/output/intergenic_sORF/"${filename%.fa}_intergenic_sORF.fna" \
				-oa $sORF_PATH_FOLDER/output/intergenic_sORF/"${filename%.fa}_intergenic_sORF.faa" \
				-r $sORF_PATH_FOLDER/output/intergenic_sORF/"${filename%.fa}_intergenic_sORF_for_ribo.txt" \
				-g $sORF_PATH_FOLDER/output/intergenic_sORF/"${filename%.fa}_intergenic_sORF.bed"
	done
}

blastn_analysis(){
		mkdir -p $sORF_PATH_FOLDER/output/conservation
		cat $sORF_PATH_FOLDER/reference_sequences/*.fa > $sORF_PATH_FOLDER/output/conservation/all_related.fa
		makeblastdb -in $sORF_PATH_FOLDER/output/conservation/all_related.fa -dbtype nucl
		for file in $sORF_PATH_FOLDER/output/intergenic_sORF/NC_011916*intergenic_sORF.fna
		do
		filename=${file##*/}
		/home/lei/software/ncbi-blast-2.2.29+/bin/blastn \
			-query "$file" \
			-db $sORF_PATH_FOLDER/output/conservation/all_related.fa \
			-outfmt 6 -evalue 10 -word_size 10 \
			-out $sORF_PATH_FOLDER/output/conservation/"${filename%.fna}_blast.tab" \
			-num_threads 30
		done
}

blastn2alignment(){
	#parse blastn result and format to alignment format
	#for file in $sORF_PATH_FOLDER/output/conservation/*blast.tab
	#do
	#filename=${file##*/}
	#filetag=${filename%_blast.tab}
	#perl bin/bla2aln.pl -b "$file"
	#done
	parallel -j 24 'perl bin/bla2aln.pl -b {}' ::: $sORF_PATH_FOLDER/output/conservation/NC_011916*blast.tab

}

run_multiple_sequence_alignment(){
	# perform mulitple sequence alignment
	for mfa in sORF_analysis/output/MFA/NC_011916*.tab/*.fasta
	do
	echo "$mfa"
	clustalw -align -infile="$mfa" -outfile="$mfa.aln" -outorder=input
	done
}

run_RNAcode(){
	# run coservation score
	BIN_FOLDER=~/software/RNAcode-0.3/src
	for aln in sORF_analysis/output/MFA/NC_011916*.tab/*.aln
	do
	${BIN_FOLDER}/RNAcode --best-only "$aln" \
		--outfile "${aln%.aln}_RNAcode.out" \
		--cutoff 0.01
	done
}

sum_RNAcode_output(){
	#This purpose is to retrieve conservation score from RNAcode output
	for file in sORF_analysis/output/MFA/NC_011916*.tab
	do
		#please note that 10 means 10 species
		grep -c ">" ${file}/*.fasta|sed 's/_.fasta:/\t/g' |awk '{print $1,$2/10}'|sed 's/^.*\///' > "${file%.tab}.txt"
		for single in ${file}/*RNAcode.out
		do
		echo -e "$single\t$(sed -n '4p' "$single"|awk '{print $8}'| \
			sed 's/used://')"| \
			awk 'BEGIN { FS = OFS = "\t" } { for(i=1; i<=NF; i++) if($i ~ /^ *$/) $i = 0 }; 1'| \
			sed 's/__RNAcode.out//' |sed 's/^.*\///'
		done > "${file%.tab}_RNAcode.txt"
	done
}

run_Ribo_calculation(){
	#This purpose is to calculate the translation initiation scores
	export PATH=../../src/nupack3.0.4/bin:$PATH
	export NUPACKHOME=../../src/nupack3.0.4
	mkdir -p $sORF_PATH_FOLDER/output/ribo_score
	#for file in $sORF_PATH_FOLDER/output/intergenic_sORF/*intergenic_sORF_for_ribo.txt
	#do
	#	filename=${file##*/}
	#	cat $file|while read -r a b; \
	#	do \
	#	echo "$a\t$b\t$(python ../../src/Ribosome-Binding-Site-Calculator-v1.0/Run_RBS_Calculator.py "$b" 20|grep "^20")"; \
	#done > $sORF_PATH_FOLDER/output/ribo_score/"${filename%.txt}_score.txt"
	#done

	parallel -j 11 'cat {} |while read -r a b; do echo -e "$a\t$b\t$(python /kauai/lei/Project/2014-02-13-Lei_Li_sORF-Salmonella/src/Ribosome-Binding-Site-Calculator-v1.0/Run_RBS_Calculator.py "$b" 20|grep "^20")";done > {.}_score.txt' ::: sORF_analysis/output/intergenic_sORF/NC_011916*intergenic_sORF_for_ribo.txt
	#mv sORF_analysis/output/intergenic_sORF/*intergenic_sORF_for_ribo_score.txt sORF_analysis/output/ribo_score/
}

cal_small_protein_seq_features(){
	#calculcate the small protein features
	mkdir -p $sORF_PATH_FOLDER/output/aa_comp
	for file in $sORF_PATH_FOLDER/output/intergenic_sORF/NC_011916*intergenic_sORF.fna
	do
		filename=${file##*/}
		docker run -v /home/lei/kauai_lei/Project/2014-02-13-Lei_Li_sORF-Salmonella/results/2016-03-22-small-protein-ATG-expanded-species:/shared/data \
		cgat/scripts fasta2table \
		-s "aa" -t na \
		--stdin=/shared/data/sORF_analysis/output/intergenic_sORF/"$filename" \
		--stdout=/shared/data/sORF_analysis/output/aa_comp/"${filename%.fna}.tsv"
	cut -f1,29,35,37,40,42-43,45 sORF_analysis/output/aa_comp/"${filename%.fna}.tsv" > sORF_analysis/output/aa_comp/"${filename%.fna}_feature.tsv"
	done
}

extract_neg_sORF_from_trRNA(){
	#purpose is to extract sORF from rRNA tRNA
	for file in $sORF_PATH_FOLDER/reference_sequences/NC_011916*.gff
	do
	filename=${file##*/}
	filetag=${filename%.gff}
	awk '$3=="tRNA"|| $3=="rRNA"' "$file" |cut -f1,4,5,7,9|sed 's/\.\S\t/\t/'| \
		while read -r a b c d e; do \
		echo -e "$a\t$b\t$c\t$e\t0\t$d"; \
	done > "${file%.gff}_rtRNA.bed"
	bedtools intersect -a sORF_analysis/output/intergenic_sORF/"${filetag}_intergenic_sORF.bed" \
		-b "${file%.gff}_rtRNA.bed" -f 1 -s > sORF_analysis/output/intergenic_sORF/"${filetag}_sORF_rtRNA.bed"
	done
}

build_phylogeny_tree_for_sORF(){
	# build phylogeny tree for genes in a family
	for tab in sORF_analysis/output/MFA/*.tab
	do
		tabname=$(basename "$tab")
		mkdir -p sORF_analysis/output/muscle/"${tabname}"
		for mfa in $tab/*.fasta
		do
		echo "$tabname"
    if [[ -s $mfa ]]; then
          perl bin/phylogeny_pipeline.pl --outdir sORF_analysis/output/muscle/"${tabname}" $mfa
    fi
		done
	done
}

run_adaptive_selection_for_sORF(){
	#run selection for sORF
	for input in sORF_analysis/output/muscle/*.muscle
	do
	perl bin/asa_pipeline.pl "$input" "${input}.nj.nhx" --outdir sORF_analysis/output/selection --verbose
	done
}


get_sORF_quanti_ecolification(){
	#Escherichia coli
	mkdir -p sORF_analysis/output/sORF_quanti_ecoli/
	awk '$6=="+"' sORF_analysis/output/intergenic_sORF/NC_000913_intergenic_sORF.bed \
		|cut -f2,3,4|while read i j k; do \
		echo -e "$k\t$i\t$j"; done \
		> sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_plus.ptt
	awk '$6=="-"' sORF_analysis/output/intergenic_sORF/NC_000913_intergenic_sORF.bed \
                |cut -f2,3,4|while read i j k; do \
                echo -e "$k\t$j\t$i"; done \
                > sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_minus.ptt

	SOURCE1=/home/lei/kauai_lei/Project/2014-01-17-Takehisa_Yano_Yanjie_Salmonella_Escherichia/2016-02-22-Ribo-Seq-Escherichia-cell-reports/Ribo_Seq_analysis/output/center_weighting
	for file in ${SOURCE1}/*_plus_read_density.txt
        do
        filename=${file##*/}
        python ~/Ribo_Seq/bin/ribotmp/gene_quantification.py \
                $file ${file%plus_read_density.txt}minus_read_density.txt \
                sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_plus.ptt \
                sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_minus.ptt \
                sORF_analysis/output/sORF_quanti_ecoli/${filename%plus_read_density.txt}plus_gene_quanti.txt \
                sORF_analysis/output/sORF_quanti_ecoli/${filename%plus_read_density.txt}minus_gene_quanti.txt
        done

	SOURCE2=/kauai/lei/Project/2014-01-17-Takehisa_Yano_Yanjie_Salmonella_Escherichia/2014-02-25-Ribo-Seq-cell-Escherihica-coli/output/center_weighting
	for file in ${SOURCE2}/*_plus_read_density.txt
        do
        filename=${file##*/}
        python ~/Ribo_Seq/bin/ribotmp/gene_quantification.py \
                $file ${file%plus_read_density.txt}minus_read_density.txt \
                sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_plus.ptt \
                sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_minus.ptt \
                sORF_analysis/output/sORF_quanti_ecoli/${filename%plus_read_density.txt}plus_gene_quanti.txt \
                sORF_analysis/output/sORF_quanti_ecoli/${filename%plus_read_density.txt}minus_gene_quanti.txt
        done

	SOURCE3=/kauai/lei/Project/2014-01-17-Takehisa_Yano_Yanjie_Salmonella_Escherichia/2014-02-24-Ribo-Seq-nature-Escherichia-coli/output/center_weighting
	for file in ${SOURCE3}/*_plus_read_density.txt
        do
        filename=${file##*/}
        python ~/Ribo_Seq/bin/ribotmp/gene_quantification.py \
                $file ${file%plus_read_density.txt}minus_read_density.txt \
                sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_plus.ptt \
                sORF_analysis/output/sORF_quanti_ecoli/NC_000913_intergenic_sORF_minus.ptt \
                sORF_analysis/output/sORF_quanti_ecoli/${filename%plus_read_density.txt}plus_gene_quanti.txt \
                sORF_analysis/output/sORF_quanti_ecoli/${filename%plus_read_density.txt}minus_gene_quanti.txt
        done

	#Salmonella Typhimurium
	mkdir -p sORF_analysis/output/sORF_quanti_st/
        awk '$6=="+"' sORF_analysis/output/intergenic_sORF/NC_016810_intergenic_sORF.bed \
                |cut -f2,3,4|while read i j k; do \
                echo -e "$k\t$i\t$j"; done \
                > sORF_analysis/output/sORF_quanti_st/NC_016810_intergenic_sORF_plus.ptt
        awk '$6=="-"' sORF_analysis/output/intergenic_sORF/NC_016810_intergenic_sORF.bed \
                |cut -f2,3,4|while read i j k; do \
                echo -e "$k\t$j\t$i"; done \
                > sORF_analysis/output/sORF_quanti_st/NC_016810_intergenic_sORF_minus.ptt

	SOURCE4=/kauai/lei/Project/2014-01-17-Takehisa_Yano_Yanjie_Salmonella_Escherichia/2014-02-05-Ribo-profiling-ID-002068-Fragment-RNASeq-ID-002069/Ribo-Seq/output/center_weighting
	for file in ${SOURCE4}/ID-002068*_plus_read_density.txt
        do
        filename=${file##*/}
        python ~/Ribo_Seq/bin/ribotmp/gene_quantification.py \
                $file ${file%plus_read_density.txt}minus_read_density.txt \
                sORF_analysis/output/sORF_quanti_st/NC_016810_intergenic_sORF_plus.ptt \
                sORF_analysis/output/sORF_quanti_st/NC_016810_intergenic_sORF_minus.ptt \
                sORF_analysis/output/sORF_quanti_st/${filename%plus_read_density.txt}plus_gene_quanti.txt \
                sORF_analysis/output/sORF_quanti_st/${filename%plus_read_density.txt}minus_gene_quanti.txt
        done

}

get_high_ribo_sORF(){
	# The mv command run only once
	mv sORF_analysis/output/intergenic_sORF/NC_000913_intergenic_sORF.bed \
		sORF_analysis/output/intergenic_sORF/NC_000913_intergenic_sORF_raw.bed
	#Escherichia coli
	ls sORF_analysis/output/sORF_quanti_ecoli/*gene_quanti.txt| \
		while read i; do awk '$4>5' $i;done \
		|cut -f1|sort|uniq -c|awk '{if ($1>1) print $2}' \
		> sORF_analysis/output/sORF_quanti_ecoli/ecoli_high_ribo_sORF.txt

	cat sORF_analysis/output/sORF_quanti_ecoli/ecoli_high_ribo_sORF.txt| \
		while read i; do grep -w $i \
		sORF_analysis/output/intergenic_sORF/NC_000913_intergenic_sORF_raw.bed;done \
		> sORF_analysis/output/intergenic_sORF/NC_000913_intergenic_sORF.bed

	# The mv command run only once
	mv sORF_analysis/output/intergenic_sORF/NC_016810_intergenic_sORF.bed \
		sORF_analysis/output/intergenic_sORF/NC_016810_intergenic_sORF_raw.bed
	#Salmonella Typhimurium
	ls sORF_analysis/output/sORF_quanti_st/*gene_quanti.txt| \
		while read i; do awk '$4>2' $i;done | cut -f1 \
		> sORF_analysis/output/sORF_quanti_st/st_high_ribo_sORF.txt

	cat sORF_analysis/output/sORF_quanti_st/st_high_ribo_sORF.txt| \
		while read i; do grep -w $i \
		sORF_analysis/output/intergenic_sORF/NC_016810_intergenic_sORF_raw.bed;done \
		> sORF_analysis/output/intergenic_sORF/NC_016810_intergenic_sORF.bed
}


build_training_test_data(){
	mkdir -p sORF_analysis/output/training_data
	#positive dataset
	for file in sORF_analysis/output/sORF_mask/*known_sORF.bed
	do
	filename=${file##*/}
	filetag=${filename%_known_sORF.bed}
	cut -f4 "$file"|while read -r i; do echo -e "$(grep "$i" sORF_analysis/output/MFA/"${filetag}_intergenic_sORF_blast_RNAcode.txt")\
		\t$(grep "$i" sORF_analysis/output/MFA/"${filetag}_intergenic_sORF_blast.txt")\t \
		$(grep "$i" sORF_analysis/output/ribo_score/"${filetag}_intergenic_sORF_for_ribo_score.txt")\t \
		$(grep "$i" sORF_analysis/output/aa_comp/"${filetag}_intergenic_sORF_feature.tsv")";done \
		> sORF_analysis/output/training_data/"${filetag}_known.txt"
	done

	for file in sORF_analysis/output/training_data/*known.txt
	do
	filename=${file##*/}
	cat "$file"|while read -r i;do echo -e "${filename}\t${i}";done >> sORF_analysis/output/training_data/known_sum.txt
	done

	#negative dataset
	for file in sORF_analysis/output/intergenic_sORF/*_sORF_rtRNA.bed
	do
	filename=${file##*/}
	filetag=${filename%_sORF_rtRNA.bed}
	cut -f4 $file|sed 's/_$//'|while read i; do echo -e "$(grep "$i" sORF_analysis/output/MFA/"${filetag}_intergenic_sORF_blast_RNAcode.txt")\
			\t$(grep "$i" sORF_analysis/output/MFA/"${filetag}_intergenic_sORF_blast.txt")\t \
			$(grep "$i" sORF_analysis/output/ribo_score/"${filetag}_intergenic_sORF_for_ribo_score.txt")\t \
			$(grep "$i" sORF_analysis/output/aa_comp/"${filetag}_intergenic_sORF_feature.tsv")";done \
			> sORF_analysis/output/training_data/"${filetag}_neg.txt"
	done

	for file in sORF_analysis/output/training_data/*_neg.txt
	do
	filename=${file##*/}
  cat "$file"|while read -r i; do echo -e "$filename\t$i";done >> sORF_analysis/output/training_data/neg_sum.txt
  done

	#test dataset
	mkdir -p sORF_analysis/output/test_dataset

	#shuf -n 79
	for file in sORF_analysis/output/intergenic_sORF/NC_000913*intergenic_sORF.bed 
	do
	echo $file
	filename=${file##*/}
	filetag=${filename%_intergenic_sORF.bed}
	#cut -f4 $file|sed 's/_$//'|while read i; do echo -e "`grep $i sORF_analysis/output/MFA/${filetag}_intergenic_sORF_blast_RNAcode.txt`\
	#		\t`grep $i sORF_analysis/output/MFA/${filetag}_intergenic_sORF_blast.txt`\t \
	#		`grep $i sORF_analysis/output/ribo_score/${filetag}_intergenic_sORF_for_ribo_score.txt`\t \
	#		`grep $i sORF_analysis/output/aa_comp/${filetag}_intergenic_sORF_feature.tsv`";done \
	#		> sORF_analysis/output/test_dataset/${filetag}_all.txt
	cut -f4 $file|sed 's/_$//g'|while read i; do echo -e "`grep -w "${i}" sORF_analysis/output/MFA/${filetag}_intergenic_sORF_blast_RNAcode.txt`\
                       \t`grep -w "${i}_" sORF_analysis/output/ribo_score/${filetag}_intergenic_sORF_for_ribo_score.txt`\t \
                       `grep -w "${i}_" sORF_analysis/output/aa_comp/${filetag}_intergenic_sORF_feature.tsv`";done \
                       > sORF_analysis/output/test_dataset/${filetag}_all.txt
	done
}

convert_test_format_to_ml(){
	for file in sORF_analysis/output/test_dataset/NC_016810_all.txt \
		sORF_analysis/output/test_dataset/NC_000913_all.txt
	do
	tr '\t' ' ' < $file|sed 's/ \+ /\t/g'|sed 's/ \+/\t/g' > ${file%_all.txt}_v.txt

	# set two cutoff for translation filtering
	awk '$6>=300' ${file%_all.txt}_v.txt |cut -f1,2,6,9- | awk 'NF==10' > ${file%_all.txt}_info.txt


	#echo -e "Ribo_score,RNAcode_score,pC,pI,pL,pP,pR,pS,pV,Feature" > ${file%_all.txt}_ml.txt
	#cut -f2- ${file%_all.txt}_info.txt|while read a b c d e f g h i;
	#	do echo -e "$b\t$a\t$c\t$d\t$e\t$f\t$g\t$h\t$i\t0"|sed 's/\t/,/g';done >>${file%_all.txt}_ml.txt

	echo -e "Ribo_score,RNAcode_score,pI,pL,pV,Feature" > ${file%_all.txt}_ml.txt
	cut -f2,3,5,6,10 ${file%_all.txt}_info.txt|while read a b c d e;
		do echo -e "$b\t$a\t$c\t$d\t$e\t0"|sed 's/\t/,/g';done >> ${file%_all.txt}_ml.txt

	rm -rf ${file%_all.txt}_v.txt
	done
}

build_svm_training_model(){
	MODEL=../2015-11-02-SVM
	for file in sORF_analysis/output/training_data/*.csv
	do
		echo "cal column"
		COL=$(awk -F',' '{print (NF-1); exit}' $file)
		echo $COL
		echo "convert format"
		#python ${MODEL}/csv2libsvm.py sORF_analysis/output/training_data/training_set.csv \
		# 		sORF_analysis/output/training_data/training_set.data $COL True
		#python bin/training.py \
		#		sORF_analysis/output/training_data/training_set.data
		python ${MODEL}/csv2libsvm.py $file \
		 		${file%.csv}.data $COL True
		python bin/training.py \
				${file%.csv}.data
	done
	#echo "scale the value"
	#svm-scale -l -1 -u 1 -s range ${file%.csv}.data > ${file%.csv}.scale
	#echo "parameters estimation"
	#python ${MODEL}/libsvm-3.20/tools/grid.py ${file%.csv}.data
	#echo "svm model building"
	#python ${MODEL}/libsvm-3.20/tools/easy.py \
	#	sORF_analysis/output/training_data/training_set.data
	#echo "plot roc curve"
	#python ${MODEL}/libsvm-3.20/python/plotroc.py -b 1 -v 10 -c 128.0 -g 8.0 ${file%.csv}.data
	#echo "svm accuracy"
	#svm-train -b 1 -c 32.0 -g 0.001953125 ${file%.csv}.data
}

run_svm_prediction(){
	MODEL=../2015-11-02-SVM
	for file in sORF_analysis/output/test_dataset/NC_000913_ml.txt \
		sORF_analysis/output/test_dataset/NC_016810_ml.txt
	do
	echo $file
	echo "cal column"
	COL=$(awk -F',' '{print (NF-1); exit}' "$file")
	echo "$COL"
	echo "convert format"
	python ${MODEL}/csv2libsvm.py "$file" "${file%_ml.txt}.data" "$COL" True
	#echo "scale the value"
	#svm-scale -r range ${file%.csv}.data > ${file%.csv}.scale
	python bin/training.py \
		sORF_analysis/output/training_data/training_set_w_ribo.data \
		"${file%_ml.txt}.data"
	#echo "predict the value"
	#svm-predict -b 1 ${file%.csv}.data training_set.data.model ${file%.csv}.predict
	#echo "summary"
	#paste ${file} ${file%.csv}.predict > ${file%.csv}.result
	done
}

combine_prediction_with_info(){
	for file in sORF_analysis/output/test_dataset/NC_000913_info.txt \
		sORF_analysis/output/test_dataset/NC_016810_info.txt
	do
	rm -rf ${file%_info.txt}_add_sORF.txt
	filename=${file##*/}
		cat $file|while read -r a b c d e f g h i j;
		do
		value=$(grep -w "$a" sORF_analysis/output/sORF_mask/${filename%_info.txt}_known_sORF.bed)
		echo -e "$a\t$b\t$c\t$d\t$e\t$f\t$g\t$h\t$i\t$j\t$value" >> ${file%_info.txt}_add_sORF.txt
		done

	grep -v "label" ${file%_info.txt}.data.predict > ${file%_info.txt}.data.tmp
	paste ${file%_info.txt}.data.tmp ${file%_info.txt}_add_sORF.txt > ${file%_info.txt}_sum.txt
	rm -rf ${file%_info.txt}.data.tmp
	done

	#for file in sORF_analysis/output/test_dataset/*prediction
	#do
	#filename=${file##*/}
	#filetag=${filename%_sig.csv}
	#cut -f1 $file|grep -v "^$"|while read i; do \
	#	grep -w "${i}_" sORF_analysis/output/intergenic_sORF/${filetag}_intergenic_sORF.bed; \
	#	done > ${file%.csv}.bed
	#done
}

merge_sORF(){
	for file in sORF_analysis/output/test_dataset/*sum.txt
        do
        filename=${file##*/}
        filetag=${filename%_sig.csv}
	awk '$2>0.9' $file|cut -f2 \
		|while read i; do grep $i sORF_analysis/output/intergenic_sORF/${filename%_sum.txt}_intergenic_sORF.bed; done |sort -k1,1 -k2,2n > ${file%_sum.txt}_sig.bed
	bedtools merge -s -i ${file%_sum.txt}_sig.bed -c 5,5,6 -o count,max,distinct > ${file%_sum.txt}_merge.bed
	bedtools intersect -a ${file%_sum.txt}_sig.bed -b ${file%_sum.txt}_merge.bed -f 0.98 -r -s -header > ${file%_sum.txt}_sig_final.bed
	cat ${file%_sum.txt}_sig_final.bed |while read a b c d e f; do echo -e "$a\t$b\t$c\t$d\t$e\t$f\t`grep -w "${d%_}" $file`" ;done \
		> ${file%_sum.txt}_sig_final_sum.txt
	done
	#EC
	#bedtools merge -i output/EC_intergenic_sORF_feature.bed \
	#	-c 5,5,6 -s -o count,max,distinct \
	#	> output/EC_intergenic_sORF_feature_clear.bed
	#bedtools intersect -a output/EC_intergenic_sORF_feature.gff \
	#	-b output/EC_intergenic_sORF_feature_clear.bed -f 0.98 -r \
	#	-s -header > output/EC_intergenic_sORF_feature_clear.gff
	#ST
	#bedtools merge -i output/ST_intergenic_sORF_feature.bed \
	#			-c 5,5,6 -s -o count,max,distinct \
	#			> output/ST_intergenic_sORF_feature_clear.bed
	#bedtools intersect -a output/ST_intergenic_sORF_feature.gff \
	#			-b output/ST_intergenic_sORF_feature_clear.bed -f 0.98 -r \
	#			-s -header > output/ST_intergenic_sORF_feature_clear.gff
}

blast_clust(){
	grep "Enterobacteriaceae" sORF_analysis/Entero_species/*.gbk| \
			cut -d":" -f1|sort|uniq|sed 's/\.gbk//g'|sed 's/.*\/NC/NC/g' \
			> Entero_list.txt

	rm -rf $sORF_PATH_FOLDER/output/conservation/entero.fa
	cat Entero_list.txt|while read file
	do
	cat $sORF_PATH_FOLDER/reference_sequences/${file}*.fa \
		>> $sORF_PATH_FOLDER/output/conservation/entero.fa
	done
	makeblastdb -in $sORF_PATH_FOLDER/output/conservation/entero.fa -dbtype nucl

	rm -rf sORF_analysis/output/test_dataset/Entero.fna
	cat Entero_list.txt|while read file
	do
	sigfile="sORF_analysis/output/test_dataset/${file}_sig_final_sum.txt"
	filetag=${sigfile%_sig_final_sum.txt}.tag
	seqfile=${sigfile%.txt}.fna
	echo "$sigfile"
	cut -f4 $sigfile > ${filetag}
	fishInWinter.pl -bf table \
			-ff fasta ${filetag} \
			sORF_analysis/output/intergenic_sORF/${file}_intergenic_sORF.fna \
			>${seqfile}
	sed -i "s|>|>${file}_|g" ${seqfile}
	cat ${seqfile} >> sORF_analysis/output/test_dataset/Entero.fna
        done

	blastclust -i sORF_analysis/output/test_dataset/Entero.fna \
			-o sORF_analysis/output/test_dataset/Entero.blast -p F \

	awk 'NF>=1' sORF_analysis/output/test_dataset/Entero.blast| \
		cut -d" " -f1 \
		> sORF_analysis/output/conservation_analysis/entero_conserv.txt
	#find sORF_analysis/output/test_dataset/*sig_final_sum.faa -type f|xargs -I FILE sed -i "s|>|>FILE|g" FILE
	#cat sORF_analysis/output/test_dataset/*sig_final_sum.faa > sORF_analysis/output/test_dataset/complete.faa
	#cd-hit -i sORF_analysis/output/test_dataset/complete.faa -o sORF_analysis/output/test_dataset/complete.clus -d 0
	#blastclust -i sORF_analysis/output/test_dataset/complete.faa -o sORF_analysis/output/test_dataset/complete.blast -p T
}

extract_high_conserved(){
	fishInWinter.pl -bf table -ff fasta \
		sORF_analysis/output/conservation_analysis/entero_conserv.txt \
		sORF_analysis/output/test_dataset/Entero.fna \
		> sORF_analysis/output/conservation_analysis/entero_conserv.fna


	/usr/bin/blastn -query sORF_analysis/output/conservation_analysis/entero_conserv.fna \
          -db $sORF_PATH_FOLDER/output/conservation/entero.fa \
          -outfmt 6 \
          -evalue 1 \
          -num_threads 18 \
          -max_hsps 1 \
	  -word_size 10 \
          -out $sORF_PATH_FOLDER/output/conservation_analysis/entero_conserv_tblast.tab

	cut -f1 sORF_analysis/output/conservation_analysis/entero_conserv_tblast.tab \
		|sort|uniq -c|sort -k1n \
		> sORF_analysis/output/conservation_analysis/entero_conserv_tblast_rank.txt
}

conservation_heatmap(){
 #cd $sORF_PATH_FOLDER/reference_sequences/
 #ls *.ptt|while read i; do echo -e "${i%.ptt}\t`head -n1 $i`";done > ../ref_list.txt

  awk '{if($1>=7) print $2}' \
	sORF_analysis/output/conservation_analysis/entero_conserv_tblast_rank.txt \
	> sORF_analysis/output/conservation_analysis/entero_conserv_7more.txt

  OUTPUT_FOLDER=sORF_analysis
  echo " "| tr '\n' '\t' > $OUTPUT_FOLDER/entero_sORF_reference_matrix.csv
  cat sORF_analysis/output/conservation_analysis/entero_conserv_7more.txt|while read PEP
  do
  echo ${PEP} | tr '\n' '\t' >>$OUTPUT_FOLDER/entero_sORF_reference_matrix.csv
  done

  cat Entero_list.txt |while read file
  do
      grep -w "$file" sORF_analysis/ref_list.txt|cut -d"," -f1;
  done > Entero_info.txt

  cat Entero_info.txt|while read REF NAME
  do
      echo "" >>$OUTPUT_FOLDER/entero_sORF_reference_matrix.csv
      echo "${NAME}"| tr '\n' '\t' >>$OUTPUT_FOLDER/entero_sORF_reference_matrix.csv
      cat sORF_analysis/output/conservation_analysis/entero_conserv_7more.txt|while read PEP
      do
	echo -e "PEP\t`grep "${PEP}.*${REF}\." sORF_analysis/output/conservation_analysis/entero_conserv_tblast.tab|head -n1`" | \
	cut -f1,4|sed 's/\t/_/g' | tr '\n' '\t' >>$OUTPUT_FOLDER/entero_sORF_reference_matrix.csv
      done
  done

  sed 's/PEP_//g' $OUTPUT_FOLDER/entero_sORF_reference_matrix.csv | \
  sed 's/PEP/0/g' > $OUTPUT_FOLDER/entero_sORF_reference_matrix.tab
}

split_sORF_from_predictions(){
	fishInWinter.pl -bf table -ff fasta --patternmode \
		$sORF_PATH_FOLDER/output/known_sORF.txt \
		$sORF_PATH_FOLDER/output/U00096.3_intergenic_nostrand_sORF.fa \
		> $sORF_PATH_FOLDER/output/known_sORF.fa
	fishInWinter.pl -bf table -ff fasta --patternmode \
				--except $sORF_PATH_FOLDER/output/known_sORF.txt \
				$sORF_PATH_FOLDER/output/U00096.3_intergenic_nostrand_sORF.fa \
				> $sORF_PATH_FOLDER/output/predicted_sORF.fa
}
run_blast_aa_db(){
	/home/lei/software/ncbi-blast-2.2.29+/bin/blastn -query $sORF_PATH_FOLDER/output/U00096.1_intergenic_nostrand_sORF.fa \
		-db ../../data/2014-12-02-U00096_3/U00096.3_48_150.fa \
		-evalue 1e-2 \
		-outfmt 6 \
		-num_threads 10 \
		-out $sORF_PATH_FOLDER/output/U00096.1_intergenic_nostrand_sORF_blast.tab
	/home/lei/software/ncbi-blast-2.2.29+/bin/blastn -query $sORF_PATH_FOLDER/output/U00096.1_intergenic_nostrand_sORF.fa \
		-db ../../data/2014-12-04-small-proteins-ecogene/small_proteins_16_50.fa \
		-evalue 1e-2 \
		-outfmt 6 \
		-num_threads 10 \
		-out $sORF_PATH_FOLDER/output/U00096.1_intergenic_ecogene_nostrand_sORF_blast.tab

}

run_blast_nr(){
	mkdir -p $sORF_PATH_FOLDER/blast_nr
	blastp -query sORF_analysis/output/conservation_analysis/entero_conserv.faa \
		-db /kauai/lei/db/nr \
		-evalue 1e-2 \
		-outfmt 5 \
		-num_threads 20 \
		-out sORF_analysis/output/conservation_analysis/entero_conserv_nr_m5.blast

	BIN=~/Ribo_Seq/bin/ribotmp/
        for file in sORF_analysis/output/conservation_analysis/entero_conserv_nr_m5.blast
        do
        perl $BIN/blast_m7_m8.pl \
                -input $file \
                -out ${file%_m5.blast}.tab
        done
}




get_unmapped_hit(){
	grep "no hit found" $sORF_PATH_FOLDER/blast_nr/NC_012587_sORF.tab | \
		cut -f1 > $sORF_PATH_FOLDER/blast_nr/NC_012587_sORF_unmapped.txt
	fishInWinter.pl -bf table -ff fasta $sORF_PATH_FOLDER/blast_nr/NC_012587_sORF_unmapped.txt \
		$sORF_PATH_FOLDER/output/NC_012587_sORF.fa > $sORF_PATH_FOLDER/blast_nr/NC_012587_sORF_unmapped.fa
}

get_known_sORFs(){
	mkdir -p $sORF_PATH_FOLDER/result
	awk '$6<100' $sORF_PATH_FOLDER/blast_nr/NC_012587_sORF.tab \
		|grep -v "no hit found"|grep -v "hypothetical"|grep -v "ribosomal" \
		>$sORF_PATH_FOLDER/result/NC_012587_known_sORF.txt
}



generate_package_to_send(){
	SEND_FOLDER=XXX-Functional-annotation-analysis
	mkdir ${SEND_FOLDER}
	cp -r ${RIBO_PATH_FOLDER}/ ${SEND_FOLDER}
	zip -r ${SEND_FOLDER}.zip ${SEND_FOLDER}
}

compress_files(){
	find ${RIBO_PATH_FOLDER} -type f -print0 | xargs -n1 -0 -P24 bzip2
}

main
                                                                
