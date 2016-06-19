use strict;

my $infile = shift;

print mfa2axt($infile);



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
