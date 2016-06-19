#!/usr/local/bin/perl -w
#
#Author: Ruan Jue
#
#Description:
#NODE[
#	name,
#	branch_length,
#	ref of attributes's hash,
#	ref of ancestral NODE,
#	ref of childern NODE array, 
#	a variable(used in iterator)
#]
#
use strict;
no warnings "recursion";

=pod
my $txt = join("",<>);
$txt=~s/\s//g;

 Parse nhx
my $tree = &parse_nhx($txt);

my @leaves = &leaf_nodes($tree);
foreach my $leaf (@leaves){
	# Print a leaf
	print &nhx2string($leaf);
}

# Print whole tree
print &nhx2string($tree);

=cut

#########################################

my $txt = join("",<>);
$txt=~s/\s//g;

my $tree = &parse_nhx($txt);
print &nhx2string($tree);





#########################################


sub read_file {
	my $file = shift;
	unless(open(IN,$file)){
		warn("Cann`t open $file");
		return;
	}
	my $str = join('',<IN>);
	close IN;
	return $str;
}

sub parse_nhx_file {
	my $file = shift;
	my $txt  = &read_file($file);
	return unless($txt);
	return &parse_nhx($txt);
}

sub free_nhx {
	my $root = shift;
	foreach my $node (&suffix_iterator($root)){
		delete $node->[2];
		undef $node->[3];
		undef $node->[4];
		undef $node;
	};
}

sub parse_nhx {
	my $txt = shift();
	$txt=~s/\s//g;
	my $node = ["__ROOT__",0];
	$node->[4] = [];
	$node->[5] = 0;
	my ($pos1,$pos2);
	$pos1 = $pos2 = 0;
	while($txt=~/([(),])/g){
		$pos2   = pos($txt) - 1;
		my $op  = $1;
		my $str = substr($txt,$pos1,$pos2-$pos1);
		if($str=~/([^:\[]*)(:([0-9.]+)(\[&&NHX:([^\]]*)\])?)?/){
			my $name = $1;
			$name = '' unless($name);
			my $dist = $3;
			my $feat = $5;
			$node->[0] = $name;
			$node->[1] = $dist;
			if(defined($feat)){
				while($feat=~/([^=:]+)=([^=:]*)/g){
					$node->[2]->{$1} = $2;
				}
			}
		}
		if($op eq '('){
			my $it = [];
			$it->[2] = {};
			$it->[3] = $node;
			$it->[4] = []; #childs
			$it->[5] = 0; #a register
			$node->[4]->[$node->[5]++] = $it;
			$node = $it;
		} elsif($op eq ','){
			$node->[0] = '' unless($node->[0]);
			$node->[1] = 0 unless($node->[1]);
			$node = $node->[3];
			my $it = [];
			$it->[2] = {};
			$it->[3] = $node;
			$it->[4] = []; #childs
			$it->[5] = 0; #a register
			$node->[4]->[$node->[5]++] = $it;
			$node = $it;
		} else {
			$node->[0] = '' unless($node->[0]);
			$node->[1] = 0 unless($node->[1]);
			$node = $node->[3];
		}
		$pos1 = $pos2 + 1;
	}
	$pos2 = length($txt);
	my $str = substr($txt,$pos1,$pos2-$pos1);
	if($str=~/([^:\[]*)((:[0-9.]+)?(\[&&NHX:([^\]]*)\]?)?)/){
		my $name = $1;
		$name = '' unless($name);
		my $dist = $3;
		my $feat = $5;
		$node->[0] = $name;
		$node->[1] = $dist;
		if(defined($feat)){
			while($feat=~/([^=:]+)=([^=:]*)/g){
				$node->[2]->{$1} = $2;
			}
		}
	}
	return $node;
}

sub nhx2string {
	my $node = shift();
	my $indent = shift();
	$indent = 0 unless($indent);
	my $txt = (' ' x $indent);
	if($node->[4] and @{$node->[4]}){
		$txt .= "(\n".join(",\n",map {&nhx2string($_,$indent+1)} (@{$node->[4]}))."\n".(' ' x $indent).')';
	}
	my $name = $node->[0];
	$name=~s/\s/_/g;
	$name=~tr/(),/``~/;
	$txt .= "$name" if(defined $node->[0]);
	$txt .= ":$node->[1]" if(defined $node->[1]);
	if(keys(%{$node->[2]})){
		$txt .= "[&&NHX:";
		$txt .= join(":",map{"$_=$node->[2]->{$_}"} (keys(%{$node->[2]})));
		$txt .= "]";
	}
	$txt .= ";\n" unless($indent);
	return $txt;
}

sub string_nhx_format {
	my $txt = shift();
	$txt=~s/\s//g;
	my $line  = '';
	my $layer = 0;
	my $indent= 1;
	my $tab   = shift();
	$tab = " " unless($tab);
	my $pos1  = 0;
	my $pos2  = 0;
	while($txt=~/([(),])/g){
		$pos2 = pos($txt)-1;
		$line .= (($indent? ($tab x $layer):"").substr($txt,$pos1,$pos2-$pos1)) if($pos2-$pos1);
		$indent = 1;
		if($1 eq ','){
			$line .= ",\n";
		} elsif($1 eq '('){
			$line .= (($indent? ($tab x $layer):"")."(\n");
			$layer ++;
		} else {
			$layer --;
			$line .= ("\n".($tab x $layer).")");
			$indent = 0;
		}
		$pos1 = $pos2 + 1;
	}
	$pos2 = length($txt);
	$line .= (($indent? ($tab x $layer):"").substr($txt,$pos1,$pos2-$pos1)) if($pos2-$pos1);
	return $line;
}

# Call this function will change the extra flags
sub leaf_nodes {
	my $tree = shift();
	$tree = &parse_nhx($tree) unless(ref($tree));
	my @leaves = ();
	$tree->[5] = 0;
	my $root = $tree;
	while($tree->[5] < @{$tree->[4]}){
		while(@{$tree->[4]->[$tree->[5]]->[4]}){
			$tree = $tree->[4]->[$tree->[5]];
			$tree->[5] = 0;
		}
		push(@leaves,$tree->[4]->[$tree->[5]]);
		$tree->[5] ++;
		while($tree->[5] >= @{$tree->[4]} and $tree != $root){ $tree = $tree->[3]; $tree->[5]++;}
	}
	push(@leaves,$tree) unless(@{$tree->[4]});
	return @leaves;
}

sub find_nodes_by_feat {
	my ($tree,$key,$val) = @_;
	my @nodes = ();
	foreach my $node (&post_iterator($tree)){
		push(@nodes,$node) if(exists $node->[2]->{$key} and $node->[2]->{$key} eq $val);
	}
	return @nodes;
}

sub root_node {
	my $tree = shift();
	while($tree->[3]){$tree = $tree->[3];}
	return $tree;
}

sub lineage_nodes {
	my $tree = shift();
	my @lineage = ($tree);
	while($tree->[3]){$tree = $tree->[3];push(@lineage,$tree);}
	return reverse @lineage;
}

sub lastest_common_ancestor {
	my ($node1,$node2) = @_;
	return $node1 if($node1 == $node2);
	my @lineage1 = &lineage_nodes($node1);
	my @lineage2 = &lineage_nodes($node2);
	my $ancestor  = $lineage1[0];
	foreach my $i (0..$#lineage1-1){
		if($lineage1[$i] != $lineage2[$i]){
			return $ancestor;
		} else {
			$ancestor = $lineage1[$i];
		}
	}
	return $ancestor;
}

sub distance {
	my ($node1,$node2) = @_;
	$node2 = &root_node($node1) unless($node2);
	my $ancesor = &lastest_common_ancesor($node1,$node2);
	my $dist = 0;
	while($node1 != $ancesor){$dist += $node1->[1]; $node1 = $node1->[3];}
	while($node2 != $ancesor and defined $node2){$dist += $node2->[1]; $node2 = $node2->[3];}
	return $dist;
}

sub pre_iterator {
	my ($node, $fun, @params) = @_;
	my @nodes = ();
	$node = &parse_nhx($node) unless(ref($node));
	push(@nodes, $node);
	if($fun){
		&{$fun}($node, @params) and return ;
	}
	for my $child (@{$node->[4]}){
		my @rs = &post_iterator($child, $fun, @params);
		return unless(@rs);
		push(@nodes, @rs);
	}
	return @nodes;
}

sub post_iterator {
	my ($node, $fun, @params) = @_;
	my @nodes = ();
	$node = &parse_nhx($node) unless(ref($node));
	for my $child (@{$node->[4]}){
		my @rs = &post_iterator($child, $fun, @params);
		return unless(@rs);
		push(@nodes, @rs);
	}
	if($fun){
		&{$fun}($node, @params) and return ;
	}
	push(@nodes, $node);
	return @nodes;
}

sub suffix_iterator {
	my $root = shift;
	my $fun  = shift;
	my @params = @_;
	$root = &parse_nhx($root) unless(ref($root));
	my @nodes = ();
	my $tree = $root;
	$tree->[5] = 0;
	while($tree->[5] < @{$tree->[4]}){
		$tree = $tree->[4]->[$tree->[5]];
		$tree->[5] = 0;
		while($tree->[5] < @{$tree->[4]}){
			$tree = $tree->[4]->[$tree->[5]];
			$tree->[5] = 0;
		}
		&{$fun}($tree,@params) if($fun);
		push(@nodes,$tree);
		$tree->[5] ++;
		$tree = $tree->[3];
		$tree->[5] ++;
		while($tree->[5] >= @{$tree->[4]} and $tree != $root){ &{$fun}($tree,@params) if($fun); push(@nodes,$tree); $tree = $tree->[3]; $tree->[5] ++;}
	}
	if($tree->[5] > 0){
		&{$fun}($tree,@params) if($fun);
		push(@nodes,$tree);
	}
	return @nodes;
}

sub set_extra_flag {
	my ($tree, $flag) = @_;
	$tree->[5] = $flag;
	foreach my $node (@{$tree->[4]}){
		&set_extra_flag($node, $flag);
	}
}

sub subtree_by_flag {
	my ($tree, $flag) = @_;
	return _subtree_aux($tree, undef, $flag);
}

sub clone_node {
	my $node = shift;
	my %hash = $node->[2]? %{$node->[2]}:();
	return [$node->[0], $node->[1], \%hash, undef, [], $node->[5]];
}

sub normalize_tree {
	my $tree = shift;
	if(@{$tree->[4]} == 0){
	} elsif(@{$tree->[4]} == 1){
		@$tree = @{$tree->[4]->[0]};
		normalize_tree($tree);
	} else {
		foreach my $n (@{$tree->[4]}){
			normalize_tree($n);
		}
	}
}

sub _subtree_aux {
	my ($node, $parent, $flag) = @_;
	return unless($node->[5] == $flag);
	my $n = &clone_node($node);
	if($parent){
		$n->[3] = $parent;
		push(@{$parent->[4]}, $n);
	} else {
		$parent = $n;
	}
	foreach my $c (@{$node->[4]}){
		_subtree_aux($c, $n, $flag);
	}
	return $parent;
}

sub subtree_by_taxon {
	my ($tree, @taxons) = @_;
	my %hash = map {$_=>1} @taxons;
	my @nodes = ();
	foreach my $node (leaf_nodes($tree)){
		if(exists $node->[2]->{S}){
			push(@nodes, $node) if($hash{$node->[2]->{S}});
		} elsif($node->[0] =~/_([A-Z]+)$/){
			push(@nodes, $node) if($hash{$1});
		} elsif($node->[0] =~/^([A-Z]+)/){
			push(@nodes, $node) if($hash{$1});
		}
	}
	set_extra_flag($tree, 0);
	foreach my $node (@nodes){
		foreach my $n (lineage_nodes($node)){
			$n->[5] = 1;
		}
	}
	return subtree_by_flag($tree, 1);
}



