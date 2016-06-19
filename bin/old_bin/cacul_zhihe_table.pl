#!/usr/bin/perl

=head1 Name



=head1 Description

Only generate table of n1<=10,n2<=10;
When n1>10,n2>10, use standard normal distribution

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

my $n1 = shift || 3;
my $n2 = shift || 4;

my $n = $n1 + $n2;

my $total;
my $frequency;
my @group; ##store each group
my %zhihe;
my @a; ##globle ary for recursion used in combination()


combination($n,$n1);

##print Dumper \@group;
foreach  (@group) {
	##print "$_\n";
	my @t = split /,/;
	my $sum;
	foreach  (@t) {
		$sum += $_;
	}
	$zhihe{$sum}++;
	$total++;
}

foreach my $R1 (sort {$a<=>$b} keys %zhihe) {
	$frequency += $zhihe{$R1} / $total;
	print "$R1\t$zhihe{$R1}\t$frequency\n";
}


sub combination{
	my $m = shift;
	my $k = shift;

	for (my $i=$m; $i>=$k;$i--) {
		$a[$k] = $i;
		if ($k > 1) {
			combination($i-1,$k-1);
		}else{
			my $str = join(",",(reverse @a));
			$str =~ s/,$//;
			push @group, $str;
			
		}
	}
}
