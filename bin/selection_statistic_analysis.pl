#!/usr/bin/perl

=head1 Name

selection_statistic_analysis.pl  --  Find the positive selected loci from comparing M1 and M2 model.

=head1 Version

    Author: Li Lei <lilei.leo007@gmail.com>
    Version:1.0 Data: 2011-09-14

=head1 Description

This is to find the Model 1, Model 2, but not four models comparison

=head1 Usage
  
   perl selection_statistic_analysis [option] <file.codeml>


=head1 Exmple

  perl ../bin/selection_statistic_analysis.pl cluster.codeml

=cut

use strict;

##global variables
my ($free_parameters,$Codeml_file);
my ($log_likelihood,$df,$likelihood_diff);
my $tag=0;

$Codeml_file = shift; 

open CODE, "$Codeml_file" or die"Could not find this file:!";
print "$Codeml_file\n";
while(<CODE>){ 
	chomp();
	#if(/^lnL\(ntime\:\s+(\d+)\s+np\:\s+(\d+)\)\:\s+([\+\-]\d+)\s+[\+\-]\d+/){
	if(/^lnL\(ntime\:\s+(\d+)\s+np\:\s+(\d+)\)\:\s+(.*)\s+(.*)$/){
		if(defined($free_parameters) && defined($log_likelihood)){
			$df=$2-$free_parameters;
			$likelihood_diff=2*($3-$log_likelihood);
			if($df==2){
				if($likelihood_diff >13.8155){
					#The significant level (p-value) <0.001
				#	print"$Codeml_file\t$free_parameters\t$log_likelihood\t$2\t$3\t$df\t$likelihood_diff\n";
				}
				if($likelihood_diff >9.2103){
					#The significant level (p-value) <0.01
				#	print"$Codeml_file\t$free_parameters\t$log_likelihood\t$2\t$3\t$df\t$likelihood_diff\n";
				}
			}else{
				#print "df is not 2\n";
			}
			
		}else{
			$free_parameters=$2;
			$log_likelihood=$3;
		}
	}
	$tag=1 if/^Bayes\s+Empirical\s+Bayes/;
	if($tag>=1){
		$tag++;
		if(/\d+\*/){
			print "$_\n";
		}
	}
	
}









