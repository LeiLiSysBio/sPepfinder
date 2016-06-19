#!/usr/bin/env perl
use strict;
use Getopt::Long;
use Bio::SeqIO;
use Bio::DB::GenBank;
use Bio::Seq;
use Bio::DB::GenPept;
use Bio::DB::Fasta;
use File::Basename;

###Defination
my $blast;
my %hash;
my %count;
my %hasha;
my $tmp;
my $output;
GetOptions(
	'blast=s' =>\$blast,
	);

unless(defined ($blast)){
	die("no blast file provided");
}

### Read the hasha data
opendir(DIR,"/kauai/lei/Project/2014-02-13-Lei_Li_sORF-Salmonella/results/2016-03-22-small-protein-ATG-expanded-species/sORF_analysis/reference_sequences/")or die $!;
foreach(readdir(DIR)){
	if(/(.*)\.fa/){
		$hasha{$1}=$1;
	}
}
open BLA,"$blast" or die"Could not open this blast file";
my $bla_name = basename($blast);
my $tag;
while(<BLA>){
    chomp;
    my $gb;
    my @array=split/\t/,$_;
    my $infile=$array[0].".fasta";
    my $bla_path = "sORF_analysis/output"."/MFA/".$bla_name;
    use File::Path qw(make_path);
	eval { make_path($bla_path) };
	if ($@) {
  	print "Couldn't create $bla_path: $@";
	}
    my $out=new Bio::SeqIO(-format=>'fasta',-file=>">>$bla_path/$infile");
    ## if the alignment length is lower than 13(aa tblastx), 40(blastn)), then filtered
    next if($array[3]<=30);
    next if($array[6]>3);
    my $current=$array[0]."_$array[1]";
    next if($tag eq $current);
    $tag=$array[0]."_$array[1]";
    #print "tag:$tag\tcurrent:$current\n";
    $hash{$array[0]}=$_;
    $count{$array[0]}++;
    if($array[1]=~m/(.*)\.\d+$/){
		my $id=$1;
		if(defined($hasha{$id})){
			$array[8] = $array[8] -1;
			$array[9] = $array[9] -1;
			if($array[8] > $array[9]){
				my $length = $array[8] - $array[9] +1;
 	        		system("fastasubseq /kauai/lei/Project/2014-02-13-Lei_Li_sORF-Salmonella/results/2016-03-22-small-protein-ATG-expanded-species/sORF_analysis/reference_sequences/${id}.fa $array[9] $length  > /tmp/EbUspd.blastn2alignment_v.$$.fna");
			 	system("fastarevcomp /tmp/EbUspd.blastn2alignment_v.$$.fna >> $bla_path/$infile");
			}else{
				my $length = $array[9] - $array[8] +1;
                                system("fastasubseq /kauai/lei/Project/2014-02-13-Lei_Li_sORF-Salmonella/results/2016-03-22-small-protein-ATG-expanded-species/sORF_analysis/reference_sequences/${id}.fa $array[8] $length >> $bla_path/$infile");
    			}
			}else{
			my $save=new Bio::SeqIO(-format=>'fasta',-file=>">>/kauai/lei/Project/2014-02-13-Lei_Li_sORF-Salmonella/results/2016-03-22-small-protein-ATG-expanded-species/sORF_analysis/reference_sequences/$id.fa");
			print "accessing $id online...., Please wait!\n";
			my $gm=Bio::DB::GenBank->new(-format=>'Fasta');
			my $tmp_obj=$gm->get_Seq_by_acc($array[1]);
			$hasha{$id}=$id;
			$save->write_seq($tmp_obj);
	    		if($array[8] > $array[9]){
				$gb=Bio::DB::GenBank->new(-format=>'Fasta',-seq_start=>$array[9],-seq_stop=>$array[8],-strand=>2);
			}else{
				$gb=Bio::DB::GenBank->new(-format=>'Fasta',-seq_start=>$array[8],-seq_stop=>$array[9],-strand=>1);
			}
	    	my $obj = $gb->get_Seq_by_acc($array[1]);
	    	if($obj){
					$out->write_seq($obj);
					sleep(5);
	     	}else{
				print "$array[2]\n";
		}
		}
	}
}

