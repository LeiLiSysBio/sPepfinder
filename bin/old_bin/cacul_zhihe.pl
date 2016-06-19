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
use File::Path;  ## function " mkpath" and "rmtree" deal with directory

##get options from command line into variables and set default values
my ($Verbose,$Help);
GetOptions(
	"verbose"=>\$Verbose,
	"help"=>\$Help
);
die `pod2text $0` if ($Help);

my %group_cross;
my %group_kaks;
my %group_zhi;
my $zhi_he;

%group_cross = (
AC  =>     1 ,
AD  =>     1 ,
AE  =>     1 ,
BC  =>     1 ,
BD  =>     1 ,
BE  =>     1 ,
);


%group_kaks = (
AB  =>     0.11 ,
AC  =>     0.72 ,
AD  =>     0.53 ,
AE  =>     0.64 ,
BC  =>     0.55 ,
BD  =>     0.66 ,
BE  =>     0.47 ,
CD  =>     0.18 ,
CE  =>     0.19 ,
DE  =>     0.10
);


my $zhi_num = 1;
foreach my $group_key (sort { $group_kaks{$a} <=> $group_kaks{$b} } keys %group_kaks) {
	my $group_val = $group_kaks{$group_key};
	##print "$group_key\t$group_val\n";
	$group_zhi{$group_key} = $zhi_num;
	$zhi_he += $zhi_num if(exists $group_cross{$group_key});
	$zhi_num++;
}

print Dumper \%group_zhi;

print $zhi_he."\n";

