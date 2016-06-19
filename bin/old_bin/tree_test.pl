#!/usr/bin/perl

=head1 Name



=head1 Description



=head1 Version

  Author: Fan Wei, fanw@genomics.org.cn
  Version: 1.0,  Date: 2006-12-6
  Note:

=head1 Usage

  --verbose   output running progress information to screen  
  --help      output help information to screen  

=head1 Exmple



=cut

use strict;
use Getopt::Long;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname); 
use Data::Dumper;
use lib "$Bin/";
use Tree::nhx_svg;


##get options from command line into variables and set default values
my ($Verbose,$Help);
GetOptions(
	"verbose"=>\$Verbose,
	"help"=>\$Help
);
die `pod2text $0` if (@ARGV == 0 || $Help);

my $infile = shift;

my $tree = new Tree::nhx_svg("show_groupKaKs",1,"groupKaKs_significance",0.05,"width",800);

$tree->parse($infile,"file");

$tree->mark_tree();
##print $tree->plot();

#print $tree->split_tree();
#print $tree->string_nhx_format();

my %Attribution;

$Attribution{node_3}{RootLeftW}  = 1.53;
$Attribution{node_3}{RootLeftP}  = 0.1317;
$Attribution{node_3}{RootRightW} = 1.54;
$Attribution{node_3}{RootRightP} = 0.1316;
$Attribution{node_3}{LeftRightW} = 1.52;
$Attribution{node_3}{LeftRightP} = 0.0011;


$Attribution{node_5}{RootRightW} = 1.54;
$Attribution{node_5}{RootRightP} = 0.0016;
$Attribution{node_5}{LeftRightW} = 1.52;
$Attribution{node_5}{LeftRightP} = 0.0011;

$Attribution{node_7}{RootLeftW}  = 1.53;
$Attribution{node_7}{RootLeftP}  = 0.1317;
$Attribution{node_7}{RootRightW} = 1.54;
$Attribution{node_7}{RootRightP} = 0.1316;

$tree->add_attribution(\%Attribution);
#print $tree->string_nhx_format();
print $tree->plot();


#foreach my $p ($tree->node()) {
#	print $p->{N}."\n" if(defined $p->{N});
#}
#
#print "#####################\n";
#foreach my $p ($tree->branch()) {
#	print $p->{N}."\n" if(defined $p->{N});
#}

#print $tree->string();



##my $subtree = $tree->subtree_by_flag($tree->root(), 1);

#$tree->remove_nodes_by_flag();
#$tree->normalize_tree();
#print $tree->string_nhx_format();

#foreach my $p ($tree->branch($subtree)) {
#	print $p->{N}."\n";
#}

#foreach my $p ($tree->branch($subtree)) {
#	print $p->{N}."\n";
#}

##$tree->normalize_tree($subtree);

#
##print $tree->string_nhx_format($subtree);

#print Dumper $subtree;

#
#print "#####################\n";
#
#$tree->remove_extra_flag($tree->root());
#
#print "#####################\n";
#
#print $tree->string_nhx_format();

#foreach my $p ($tree->node()) {
#	#print $p->{N}."\n" if(defined $p->{N});
#	print $p->{N}."##  ";
#	foreach my $pp ($tree->lineage_nodes($p)) {
#		print $pp->{N}."  ";
#	}
#	print "\n";
#}


#my ($node1,$node2);
#foreach my $p ($tree->node()) {
#	$node1 = $p if($p->{N} eq "C");
#	$node2 = $p if($p->{N} eq "E");
#}
#my $ancestor = $tree->lastest_common_ancestor($node1,$node2);
#
#print $ancestor->{N}."\n";
#
#print $tree->distance($node1,$node2)."\n";
#


####################################################
################### Sub Routines ###################
####################################################
