#!/usr/bin/perl

use strict;
use Getopt::Long;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname); 
use Data::Dumper;
use lib $Bin;
use SVG;
use Tree::nhx;
use Tree::nhx_svg;

##get options from command line into variables and set default values
my ($Verbose,$Help);
GetOptions(
	"verbose"=>\$Verbose,
	"help"=>\$Help
);
die `pod2text $0` if (@ARGV == 0 || $Help);

my $nhx_file = shift;

my $nhx = Tree::nhx->new();

$nhx->parse($nhx_file, "file");

#print $nhx->info();


my $fig = Tree::nhx_svg->new("show_inter",1,"show_ruler",1);
$fig->parse($nhx_file, "file");
print $fig->plot();


####################################################
################### Sub Routines ###################
####################################################



