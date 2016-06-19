import sys,os
import re
from Bio import SeqIO
from gff3 import Gff3Parser
import argparse
import numpy as np
import matplotlib

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument(
		'-i','--minintergenic',help="minimum intergenic length")
	parser.add_argument(
	        '-min','--minlength',help="minimum length of sORFs")
	parser.add_argument(
		'-max','--maxlength',help="maximum length of sORFs")
	parser.add_argument(
		'-f','--genomefile',help="genome sequence file")
	parser.add_argument(
		'-b','--bed',help="bed file")
	parser.add_argument(
		'-on','--outfile',help="output nt file")
	parser.add_argument(
		'-oa','--outfileaa',help="output aa file")
	parser.add_argument(
		'-r','--ribodetect', help="output file or ribosome binding site detection")
	parser.add_argument(
		'-g','--gff',help="gff format")
	args = parser.parse_args()

	cds_list = []
	intergene_length = int(args.minintergenic)
	min_length = int(args.minlength)
	max_length = int(args.maxlength)
	ref = SeqIO.read(open(args.genomefile,"r"),"fasta")
	outfile = open(args.outfile, "w")
	ribofile = open(args.ribodetect,"w")
	outaafile = open(args.outfileaa,"w")
	gff_file=open(args.gff,"w")
	table = 11

	for entry in open(args.bed,"r"):
		entry = entry.rstrip().split("\t")
		last_end = int(entry[1])
		this_start = int(entry[2]) +20
		if last_end > 20:
			last_end = last_end - 20
		name = str(entry[0])
		fea_name = entry[1]+"_"+entry[2]
		if this_start - last_end >= intergene_length + 40:
			intergene_seq = str(ref.seq[last_end:this_start])
			startcodon_find =[m.start() for m in re.finditer("(?i)(atg)", intergene_seq)]
			endcodon_find = [m.start() for m in re.finditer("(?i)(taa|tga|tag)",intergene_seq)]
			for start_codon in startcodon_find:
				for end_codon in endcodon_find:
					if end_codon % 3 == start_codon % 3:
						length = end_codon - start_codon
						if length >= min_length and length <= max_length:
							start_pos = last_end + start_codon + 1
							end_pos = last_end + end_codon + 3
							sORF_seq = str(ref.seq[start_pos-1:end_pos])
							sORF_seq_upstream = str(ref.seq[start_pos-21:end_pos])
							sORF_seq_tran = str(ref.seq[start_pos-1:end_pos].translate(table,to_stop=True))
							if len(sORF_seq_tran) >= min_length/3 and len(sORF_seq_tran) <= max_length/3 \
								and len(sORF_seq_tran)*3 + 3 == len(sORF_seq):
								#print(str(start_pos) + "\t" + str(end_pos) + "\t" \
								#		"+" + "\t" + str(sORF_seq) + "\t" + str(sORF_seq_tran))
								outfile.write(">" + str(start_pos) + "_" + \
									str(end_pos) + "+_\n" + str(sORF_seq) + "\n")
								outaafile.write(">" + str(start_pos) + "_" + \
									str(end_pos) + "+_\n" + str(sORF_seq_tran) + "\n")
								ribofile.write(str(start_pos) + "_" + str(end_pos) + "+_\t" + str(sORF_seq_upstream) + "\n")
								ribo_name=str(start_pos) + "_" + str(end_pos) + "+_"
								gff_file.write(name +"\t" + str(start_pos) + "\t" + str(end_pos) +"\t" + str(ribo_name) +"\t0\t+\n")
			intergene_seq_rev = str(ref.seq[last_end:this_start].reverse_complement())
			startcodon_find_rev =[m.start() for m in re.finditer("(?i)(atg)", intergene_seq_rev)]
			endcodon_find_rev = [m.start() for m in re.finditer("(?i)(taa|tga|tag)",intergene_seq_rev)]
			for start_codon in startcodon_find_rev:
				for end_codon in endcodon_find_rev:
					if end_codon % 3 == start_codon % 3:
						length = end_codon - start_codon
						if length >= min_length and length <= max_length:
							start_pos = this_start - end_codon - 2
							end_pos = this_start - start_codon
							sORF_seq = str(ref.seq[start_pos-1:end_pos].reverse_complement())
							sORF_seq_upstream = str(ref.seq[start_pos-1:end_pos+20].reverse_complement())
							sORF_seq_tran = str(ref.seq[start_pos-1:end_pos].reverse_complement().translate(table,to_stop=True))
							if len(sORF_seq_tran) >= min_length/3 and len(sORF_seq_tran) <= max_length/3 \
								and len(sORF_seq_tran)*3 + 3 == len(sORF_seq):
								#print(str(start_pos) + "\t" + str(end_pos) + "\t" \
								#	"-_" + str(sORF_seq_tran) + "\t" + str(sORF_seq) + "\t")
								outfile.write(">" + str(start_pos) + "_" + \
									str(end_pos) + "-_\n" + str(sORF_seq) + "\n")
								outaafile.write(">" + str(start_pos) + "_" + \
									str(end_pos) + "-_\n" + str(sORF_seq_tran) + "\n")
								ribofile.write(str(start_pos) + "_" + str(end_pos) + "-_\t" + str(sORF_seq_upstream) + "\n")
								ribo_name=str(start_pos) + "_" + str(end_pos) + "-_"
								gff_file.write(name +"\t" + str(start_pos) + "\t" + str(end_pos) +"\t" + str(ribo_name) +"\t0\t-\n")

if __name__ == '__main__':
	main()
