#!/usr/bin/perl

BEGIN {unshift @INC,"$ENV{PIPELINE}/bin";}
die "\n\nContact: fanw\@genomics.org.cn\n\n" if(@ARGV == 0);
use Tree::nhx;
use strict;
use Getopt::Long;
my $Kaks_Calculator;
my $njtree;
my $infile;
my $build;
my $bmodel;
my $Kmodel;
GetOptions("kaks=s"=>\$Kaks_Calculator,
						"njtree=s"=>\$njtree,
						"seq=s"=>\$infile,
						"build=s"=>\$build,
						"bmodel=s"=>\$bmodel,
						"kmodel=s"=>\$Kmodel);

my $file_core = $infile;
$file_core =~ s/\.[^\.]+$//;

##generate single leaf tree
my ($seq_num,@leaf_name);
open IN, $infile || die "fail open $infile\n";
$/=">"; <IN>; $/="\n";
while (<IN>) {
	push (@leaf_name, $1) if(/^(\S+)/);
	$/=">";
	my $seq = <IN>;
	$/="\n";
	$seq_num++;
}
close IN;
if ($seq_num == 1) {
	open OUT, ">$file_core.nhx" || die "fail open $file_core.nhx\n";
	print OUT $leaf_name[0].";";
	close OUT;
	exit;
}


if ($build eq "nj") {
	`$njtree nj -t $bmodel \"$infile\" > \"$file_core.nj\" 2> /dev/null`;
}elsif($build eq "ml"){
	if ($seq_num == 2) {
		open OUT, ">$file_core.nj" || die "fail open $file_core.nj\n";
		print OUT "($leaf_name[0]:1,$leaf_name[1]:1);";
		close OUT;
	}elsif($seq_num > 2){
		#print "$njtree phyml -n -m $bmodel \"$infile\" > \"$file_core.nj\" 2> /dev/null\n";
		`$njtree phyml -n -m $bmodel \"$infile\" > \"$file_core.nj\" 2> /dev/null`;
		
		#print "$njtree root \"$file_core.nj\" > \"$file_core.nj.root\"\n";
		`$njtree root \"$file_core.nj\" > \"$file_core.nj.root\"`;
		`mv \"$file_core.nj.root\" \"$file_core.nj\"`;
		
		my $nhx = Tree::nhx->new();
		$nhx->parse("$file_core.nj","file");
		$nhx->sort_tree;
		
		open OUT,">$file_core.nj.sort" || die "fail creat $file_core.nj.sort";
		print OUT $nhx->string($nhx->root, "nhx");
		close OUT;
		undef($nhx);
		
		`mv \"$file_core.nj.sort\" \"$file_core.nj\"`;
	}
}



## only caculate Ka/Ks when sequence number <= 200
if ($seq_num <= 200) {

	##caculate Ka and Ks
	open OUT,">$file_core.axt" || die "fail to creat $file_core.axt\n";
	print OUT &mfa2axt($infile);
	close OUT;

	#print $file_core,"\n";
	#print "$Kaks_Calculator -m $Kmodel -i \"$file_core.axt\" -o \"$file_core.KaKs\"\n";
	`$Kaks_Calculator -m $Kmodel -i \"$file_core.axt\" -o \"$file_core.KaKs\"`;

	my ($Ka_matrix, $Ks_matrix) = &get_KaKs_matrix("$file_core.KaKs");
	open OUT,">$file_core.KaKs.Ka.matrix" || die "fail to creat $file_core.KaKs.Ka.matrix\n";
	print OUT $Ka_matrix;
	close OUT;
	open OUT,">$file_core.KaKs.Ks.matrix" || die "fail to creat $file_core.KaKs.Ks.matrix\n";
	print OUT $Ks_matrix;
	close OUT;

	##put Ka and Ks onto branches
	#print "$njtree estlen \"$file_core.nj\" \"$file_core.KaKs.Ks.matrix\" Ds > \"$file_core.nj.Ks\"\n";	
	`$njtree estlen \"$file_core.nj\" \"$file_core.KaKs.Ks.matrix\" Ds > \"$file_core.nj.Ks\"`;
	
	#print "$njtree estlen \"$file_core.nj.Ks\" \"$file_core.KaKs.Ka.matrix\" Dn > \"$file_core.nj.Ks.Ka\"\n";
	`$njtree estlen \"$file_core.nj.Ks\" \"$file_core.KaKs.Ka.matrix\" Dn > \"$file_core.nj.Ks.Ka\"`;

}


##put Ka/Ks onto branches

if (!-f "$file_core.nj.Ks.Ka") {
	warn "[$file_core.nj.Ks.Ks] not exists!\n";
	system("cp \"$file_core.nj\" \"$file_core.nj.Ks.Ka\"");
}

my $nhx = Tree::nhx->new();
$nhx->parse("$file_core.nj.Ks.Ka","file");
foreach my $p ($nhx->node) {
	if(defined $p->{Dn} && defined $p->{Ds}){
		if ($p->{Ds} > 0){
			my $W_vaule = $p->{Dn} / $p->{Ds};
			if ($W_vaule >= 0.01 && $W_vaule <= 100) {
				$p->{W} = sprintf("%.2f",$W_vaule);
			}else{
				$p->{W} = sprintf("%.2e",$W_vaule);
			}
			
		}else{
			$p->{W} = "--"; ## modify by fanwei at 2006-11-15
		}
	}
}
open OUT,">$file_core.nhx" || die "fail creat $file_core.nhx";
print OUT $nhx->string($nhx->root,"nhx");
close OUT;

`rm \"$file_core.axt\" \"$file_core.KaKs\"`;
`rm \"$file_core.KaKs.Ka.matrix\" \"$file_core.KaKs.Ks.matrix\"`;
`rm \"$file_core.nj\" \"$file_core.nj.Ks\" \"$file_core.nj.Ks.Ka\"`;


############################################################

##get matrix of Ka an Ks form KaKs_caculator's result
sub get_KaKs_matrix{
	my $KaKs_file = shift;
	my (%Ka,%Ks,$output_Ka,$output_Ks);

	open IN, $KaKs_file || die "fail open $KaKs_file\n";
	while (<IN>) {
		my @t = split /\s+/;
		if($t[0] =~ /([^&]+)&([^&]+)/){
			$Ka{$1}{$2} = $t[2];
			$Ka{$2}{$1} = $t[2];
			$Ks{$1}{$2} = $t[3];
			$Ks{$2}{$1} = $t[3];
			
			$Ka{$1}{$1} = 0.000000;
			$Ka{$2}{$2} = 0.000000;
			$Ks{$1}{$1} = 0.000000;
			$Ks{$2}{$2} = 0.000000;

		}
	}
	close IN;

	my $num = keys %Ka;
	$output_Ka = "   $num\n";
	foreach my $first (sort keys %Ka) {
		$output_Ka .= sprintf("%-10s  ",$first);
		my $pp = $Ka{$first};
		foreach my $second (sort keys %$pp) {
			$output_Ka .= sprintf("%.6f\t",$pp->{$second});
		}
		$output_Ka =~ s/\t$//;
		$output_Ka .= "\n";
	}

	my $num = keys %Ks;
	$output_Ks = "   $num\n";
	foreach my $first (sort keys %Ks) {
		$output_Ks .= sprintf("%-10s  ",$first);
		my $pp = $Ks{$first};
		foreach my $second (sort keys %$pp) {
			$output_Ks .= sprintf("%.6f\t",$pp->{$second});
		}
		$output_Ks =~ s/\t$//;
		$output_Ks .= "\n";
	}

	return ($output_Ka,$output_Ks);

}

##get matrix of Ka an Ks form KaKs_caculator's result
sub mfa2axt{
	my $mfa_file = shift;
	my (%name_seq,%pair,$output);

	open IN, $mfa_file || die "fail open $mfa_file\n";
	$/=">"; <IN>; $/="\n";
	while (<IN>) {
		my $name = $1 if(/^(\S+)/);
		$/=">";
		my $seq = <IN>;
		chomp $seq;
		$seq =~ s/\s//g;
		$/="\n";
		$name_seq{$name} = $seq;
	}
	close IN;

	foreach my $first (sort keys %name_seq) {
		foreach my $second (sort keys %name_seq) {
			next if($first eq $second || exists $pair{"$second&$first"});
			$pair{"$first&$second"} = 1;
		}
	}

	foreach (sort keys %pair) {
		if (/([^&]+)&([^&]+)/) {
			$output .= $_."\n".$name_seq{$1}."\n".$name_seq{$2}."\n\n";
		}
	}
	return $output;

}
