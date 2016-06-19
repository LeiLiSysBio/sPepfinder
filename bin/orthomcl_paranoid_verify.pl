#!/usr/bin/perl -w
=head1 Name

orthomcl_paranoid_verify.pl -d nucletiode_directory -o output_directory

=head1 Description

The programs were trying to compare the orthlog of each strain


=head1 Version

    Author: Li Lei <lilei.leo007@gmail.com>
    Version: 1.0 Data: 2011-08-29
    Version:1.1 Data: 2011-09-04
    Version: 1.2 Data: 2011-09-06
=head1 Usage
  
   perl multiparanoid_result.pl [option] 
   --i          set the input nucletiode directory
   --o          set the output directory, default "./"
   --m          The sql ortholog output by Multiparanoid
   --help       output help information to screen  

=head1 Exmple

  perl /store/king/share/lilei/bin/multiparanoid_result.pl
  -i /store/king/share/lilei/alignment/ST_paper_data/genome/nucletiode
  -o /store/king/share/lilei/alignment/ST_paper_data/genome/multiparanoid
  -m /store/king/share/lilei/alignment/ST_paper_data/genome/ST_ortholog.sql

=cut
use strict;
use Getopt::Long;

##Global variables
my ($indir,$outfile,$infile);
my $help;
my $tag;

##Get options from command line
GetOptions(
    "indir:s" =>\$indir,
    "outdir:s" =>\$outfile,
    "infile=s" =>\$infile,
);
#die 'Please see the usage' if(@ARGV <2 || $help);

## set out directory
$infile ||=".";
$outfile=~s/\/$//;

open INFILE,"$infile" or die"Could not open this file:!";
while(<INFILE>){
    chomp();
    #print "$_\n";
    next if(/.*\,.*/);
    next if(/^Ortholog/);
    my @array=split/\t/,$_;
    print "$array[0]\t";
    if($array[0]=~/^OG/){
    my $i;
    for($i=1;$i<=$#array;$i++){
        if(!$array[$i]){
            print "\t";
        }else{
             my @new_array=split/\|/,$array[$i];
            # print "$new_array[1]\n";
             system("grep -w '$new_array[1]' $indir/cluster*");
            #exit;
            }
        }
    }
}


