import sys
import shutil

input_fh = open(sys.argv[1])
header = input_fh.readline()
if len(header.split()[0].split("|")) != 5:
    sys.stderr.write("Unexprected fasta header: \"%s\"\n" % header[:-1])
    sys.exit(2)
tmp_file_path = sys.argv[1] + "_TMP"
output_fh = open(tmp_file_path, "w")
genome_accession = header.split("|")[3]
new_header = ">%s %s" % (genome_accession, header[1:-1]) 
output_fh.write(new_header + "\n")
output_fh.write("".join(input_fh.readlines()))
shutil.move(tmp_file_path, sys.argv[1])
