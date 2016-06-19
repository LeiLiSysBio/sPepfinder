## parse nh or nhx format tree text
## Creat on: 2006-3-28

##Node: hash structure
##C       ARRAY(0x7a1d60)
##N       AB
##P       HASH(0x7a20c0)
##dist    0.1

##function provided:
##root, node, leaf, branch, info, parse, string, string_nhx_format,
##add_character, sort_tree,  remove_root, lineage_nodes, lastest_common_ancestor, distance
##subtree_by_taxon, clone_node, set_extra_flag, remove_extra_flag, remove_nodes_by_flag, normalize_tree
##mark_tree, split_tree
##node 遍历顺序是：左、右、根，属后序遍历
##branch 遍历顺序是：根、左、右，属前序遍历
##尚缺一种中序遍历方法：左、根、右

package Tree::nhx;
use strict;
use Data::Dumper;


## 按照前序遍历, 为节点添加属性
sub add_attribution {
	my $self = shift;
	my $hash = shift;
	my $root = shift || $self->root();
	my $mark = 1;
	foreach my $node ($self->branch($root)) {
		my $name = "node_$mark";
		if (exists $hash->{$name}) {
			my $name_p = $hash->{$name};
			foreach my $key (keys %$name_p) {
				$node->{$key} = $name_p->{$key};
			}
		}
		$mark++;
	}
}

## 按照前序遍历, 为节点设置mark,以防没有名字造成混乱
sub mark_tree {
	my $self = shift;
	my $root = shift || $self->root();
	my $mark = 1;
	foreach my $node ($self->branch($root)) {
		$node->{mark} = $mark;
		$node->{N} = "node_$mark" if(! exists $node->{N});
		$mark++;
	}
}

##以完全二叉树为前提
sub split_tree {
	my $self = shift;
	my $root = shift || $self->root();
	my $mark = 1;
	my $output;

	my @all_nodes = $self->leaf($root);
	
	foreach my $node ($self->branch($root)) {
		if (exists $node->{C} && @{$node->{C}} == 2) {
			my (%root_nodes,%left_nodes,%right_nodes);
			%left_nodes = map {$_=>1} $self->leaf($node->{C}[0]);
			%right_nodes = map {$_=>1} $self->leaf($node->{C}[1]);
			foreach my $name (@all_nodes) {
				if (!exists $left_nodes{$name} && !exists $right_nodes{$name}) {
					$root_nodes{$name} = 1;
				}
			}
			$output .= ">Split tree at node: node_$mark\n";
			$output .= "root_branch: ". join(" ",keys %root_nodes)."\n";
			$output .= "left_branch: ". join(" ",keys %left_nodes)."\n";
			$output .= "right_branch: ". join(" ",keys %right_nodes)."\n\n";
		}
		$mark++;
	}

	return $output;
}

## creat a new obejct, and set the parameters
sub new
{	
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {
		_node=>undef,				_root=>undef,
		_n_leaf=>undef,				_error=>undef,
		@_ } ;
	bless($self, $class);
	return $self;
}

sub root{
	my $self = shift;
	return $self->{_root};
}

## recursive order: left, right, middle
sub node{
	my $self = shift;
	return @{$self->{_node}};
}



## return leaf names
sub leaf{
	my $self = shift;
	my $root = shift || $self->root();
	my @ary;
	foreach my $p ($self->branch($root)) {
		push @ary, $p->{N} if(defined $p->{N} && ! exists $p->{C});
	}
	return @ary;
}




## add atrributions to the tree according to node name
sub add_character{
	my $self = shift;
	my ($name, $hash) = @_ ;
	my $array=$self->{_node};
	
	foreach my $p (@$array) {
		$p->{$name} = $hash->{$p->{N}} if (defined $hash->{$p->{N}});
	}	
}


##output basic information of all the nodes
sub info{
	my $self=shift;
	my $output;
	
	my $star_line = '*' x 50;
	foreach my $p ($self->node) {
		$output .= "\n$star_line\n\n" ;
		foreach my $key (sort keys %$p) {
			my $val = $p->{$key};
			$output .=  "$key\t$val\n";
			
		}
	}
	return $output;
}

## sort the tree according to children number of each node
sub sort_tree{
	my $self = shift;
	foreach my $p ($self->branch) {
		if (exists $p->{C}) {
			my $first = $self->branch($p->{C}[0]);
			my $last  = $self->branch($p->{C}[-1]);
			if ( $first < $last ) {
				my $tp = $p->{C}[0];
				$p->{C}[0] = $p->{C}[-1];
				$p->{C}[-1] = $tp;
			}
			
		}
	}
}


##recursive order: middle,left,right
##when add tags, be alert to shift out root node as the first element;
sub branch{
	my $self=shift;
	my $root=(@_) ? shift : $self->{_root};	
	my @ary;
	$self->branch_aux($root,\@ary);
	return @ary;
}

sub branch_aux{
	my $self=shift;
	my $root=shift;	
	my $ary_p = shift;
	
	push @$ary_p,$root;
	
	## very,very,very important, for the leaf node should not have "C" hash-field
	if (exists $root->{C}){
		foreach my $child_p (@{$root->{C}}) {
			$self->branch_aux($child_p,$ary_p);		
		}	
	}
}



##change rooted tree to non-rooted tree
sub remove_root{
	my $self = shift;
	my @leaf = $self->leaf;
	my $root = $self->root;
	my @child = @{$root->{C}} if(exists $root->{C}); ##children 
	
	return if(@leaf == 2 || @child != 2);
	
	my $left_p = $child[0];
	my $right_p = $child[1];
	my $left_num = $self->branch($left_p);
	my $right_num = $self->branch($right_p);
	
	if ($left_num <= $right_num) {
		unshift @{$right_p->{C}},$left_p;
		$left_p->{dist} += $right_p->{dist};
		$self->{_root} = $right_p;
	}else{
		push @{$left_p->{C}},$right_p;
		$right_p->{dist} += $left_p->{dist};
		$self->{_root} = $left_p;
	}
}


##this function is copied from Runjue's nhx_parser.pl
sub string_nhx_format {
	my $self = shift;
	my $root = (@_) ? shift : $self->{_root} ;
	my $type = (@_) ? shift : 'nhx' ; # output as nh or nhx format

	my $txt = $self->string($root,$type);
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
	return $line."\n";
}



##return tree string in nhx text format
##this function is copied from treefam latest package
sub string
{
	my $self = shift;
	my $root = (@_) ? shift : $self->{_root} ;
	my $type = (@_) ? shift : 'nhx' ; # output as nh or nhx format
	return $self->string_aux($root,$type) . ";\n";
}

##invoked in string()
sub string_aux
{
	my ($self, $root,$type) = @_;
	my $str;
	if (exists $root->{C}) {
		$str = '(';
		for my $p (@{$root->{C}}) {
			$str .= $self->string_aux($p,$type) . ",\n";
		}
		chop($str); chop($str); # chop the trailing ",\n"
		$str .= "\n)";
		$str .= $root->{N} if ($root->{N}); # node name
		$str .= ":" . $root->{dist} if (defined($root->{dist}) && $root->{dist} >= 0.0); # length
		{ # nhx block
			my $s = '';
			foreach my $p (sort keys %$root) { next if($p eq 'C' || $p eq 'P' || $p eq 'N' || $p eq 'dist'); $s .= ":$p=".$root->{$p}; }
			$str .= "[&&NHX$s]" if ($s && $type eq 'nhx');
		}
	} else { # leaf
		$str = $root->{N};
		$str .= ":" . $root->{dist} if (defined($root->{dist}) && $root->{dist} >= 0.0);
		{ # nhx block
			my $s = '';
			foreach my $p (sort keys %$root) { next if($p eq 'C' || $p eq 'P' || $p eq 'N' || $p eq 'dist'); $s .= ":$p=".$root->{$p}; }
			$str .= "[&&NHX$s]" if ($s && $type eq 'nhx');
		}
	}
	return $str;
}


## get lineages nodes for a specified node
sub lineage_nodes {
	my $self = shift;
	my $node = shift;
	my @lineage = ($node);
	while($node->{P}){$node = $node->{P};push(@lineage,$node);}
	return reverse @lineage;
}

## get the latest common ancestor node for two nodes
sub lastest_common_ancestor {
	my $self = shift;
	my ($node1,$node2) = @_;
	return $node1 if($node1 == $node2);
	my @lineage1 = $self->lineage_nodes($node1);
	my @lineage2 = $self->lineage_nodes($node2);
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

## caculate distance between two nodes, or caculate distance from root to one node
sub distance {
	my $self = shift;
	my ($node1,$node2) = @_;
	$node2 = $self->root() unless($node2);
	my $ancesor = $self->lastest_common_ancestor($node1,$node2);
	my $dist = 0;
	while($node1 != $ancesor){$dist += $node1->{dist}; $node1 = $node1->{P};}
	while($node2 != $ancesor and defined $node2){$dist += $node2->{dist}; $node2 = $node2->{P};}
	return $dist;
}



##get a subtree which contains specified species
sub subtree_by_taxon {
	my ($self,$tree, $taxons) = @_;
	$tree ||= $self->root();
	$taxons ||= ["HUMAN","PIG","MOUSE","CAEEL"];

	my %hash = map {$_=>1} @$taxons;
	my @nodes = ();
	foreach my $node ($self->branch($tree)){
		next if(exists $node->{C});
		if(exists $node->{S}){
			push(@nodes, $node) if(exists $hash{$node->[2]->{S}});
		} elsif($node->{N} =~/_([A-Z]+)$/){
			push(@nodes, $node) if(exists $hash{$1});
		} elsif($node->{N} =~/^([A-Z]+)/){
			push(@nodes, $node) if(exists $hash{$1});
		}
	}
	$self->set_extra_flag($tree, 0);
	foreach my $node (@nodes){
		foreach my $n ($self->lineage_nodes($node)){
			$n->{flag} = 1;
		}
	}
	$self->remove_nodes_by_flag($tree);
	$self->normalize_tree($tree);

	$self->remove_extra_flag($tree);
}




## clone all the contents of a node
sub clone_node {
	my $self = shift;
	my $node = shift;
	
	my %hash;
	foreach my $key (keys %$node) {
		$hash{$key} = $node->{$key} if($key ne "P" && $key ne "C");
	}

	return \%hash;
}

##set the flag variable for whole tree, and all set to 0
sub set_extra_flag {
	my ($self,$tree,$flag) = @_;
	$tree ||= $self->root();
	$flag ||= 0;
	
	$tree->{flag} = $flag;
	if (exists $tree->{C}) {
		foreach my $node (@{$tree->{C}}){
			$self->set_extra_flag($node);
		}
	}	
}

##set the flag variable for whole tree, and all set to 0
sub remove_extra_flag {
	my ($self,$tree) = @_;
	$tree ||= $self->root();
	delete $tree->{flag} if(exists $tree->{flag});

	if (exists $tree->{C}) {
		foreach my $node (@{$tree->{C}}){
			$self->remove_extra_flag($node);
		}
	}	
}


##remove unwanted nodes by flag 0 
sub remove_nodes_by_flag {
	my $self = shift;
	my $tree = shift || $self->root();

	foreach my $node ($self->branch($tree)) {
		if ($node->{flag} == 0 && exists $node->{P}{C}) {
			for (my $i=0; $i<@{$node->{P}{C}}; $i++) {
				if ($node->{P}{C}[$i] == $node) {
					splice(@{$node->{P}{C}},$i,1);
				}
			}
		}
	}
}



## change single node into normal format
sub normalize_tree {
	my $self = shift;
	my $tree = shift || $self->root();

	return unless(exists $tree->{C});
	
	if(@{$tree->{C}} == 1 && exists $tree->{P}{C}){
		for (my $i=0; $i<@{$tree->{P}{C}}; $i++) {
			if ($tree->{P}{C}[$i] == $tree) {
				$tree->{P}{C}[$i] = $tree->{C}[0];
				$tree->{C}[0]{dist} += $tree->{dist};
				$tree->{C}[0]{P} = $tree->{P};
			}
		}
			
		$self->normalize_tree($tree->{C}[0]);
	} else {
		foreach my $node (@{$tree->{C}}){
			$self->normalize_tree($node);
		}
	}
}



## parse nhx format into tree structure, 双向链表树，既指向子节点C（数组元素以示顺序），又指向母节点P。
sub parse
{
	my ($self, $str, $type) = @_;
	my ($array, @stack);
	$self->{_error} = 0;
	@{$self->{_node}} = ();
	$array = $self->{_node}; ## $array 是node节点数组的指针
	
	if ($type eq "file") {
		open IN, $str || die "fail to open $str\n";
		$str = "";
		while (<IN>) {
			$str .= $_;
		}
		close IN;
	}

	$_ = $str;
	s/\s//g;
	
	##single leaf tree
	if (!/\(.+?\)/) {
		my %hash;
		$hash{N} = $1 if(/^([^,:;\[\]]+)/);
		push @{$self->{_node}},\%hash;
		$self->{_root} = \%hash;
		$self->{_n_leaf} = 1;
		return;
	}
	
	
	##multi node tree, at least 2 leaf
	s/(\(|((\)?[^,;:\[\]\(\)]+|\))(:[\d.eE\-]+)?(\[&&NHX[^\[\]]*\])?))/&parse_aux($self,$array,\@stack,$1,$3,$4,$5)/eg;
	if (@stack != 1) {
		my $count = @stack;
		warn(qq{[parse] unmatched "(" ($count)});
		$self->{_error} = 1;
		@stack = ();
	}
	if ($self->{_error} == 0) {
		$self->{_root} = shift(@stack);
	} else {
		@{$self->{_node}} = ();
		delete($self->{_root});
	}
	if ($self->{_root}) {
		my $j = 0;
		foreach my $p (@{$self->{_node}}) {
			++$j unless ($p->{C});
		}
		$self->{_n_leaf} = $j;
	}
	return $self->{_root};
}

## invoked in parse(), parse basic unit of nhx format 
sub parse_aux
{
	my ($self, $array, $stack, $str, $name, $dist, $nhx) = @_;
	if ($str eq '(') {
		push(@$stack, $str);
	} elsif ($name) {
		my %hash;
		if ($name =~ /^\)/) {
			my (@s, $t);
			while (($t = pop(@$stack))) {
				last if (ref($t) ne 'HASH');
				push(@s, $t);
			}
			unless (defined($t)) {
				warn('[parse_aux] unmatched ")"');
				$self->{_error} = 1;
				return;
			}
			foreach (@s) {
				#push(@{$hash{C}}, $_);##original code, with right to left order
				unshift(@{$hash{C}}, $_); ##changed by self, with left to right order
				$_->{P} = \%hash;
			}
			$hash{N} = substr($name, 1) if (length($name) > 1);
		} else {
			$hash{N} = $name;
		}
		$hash{dist} = substr($dist, 1) if ($dist);
		$nhx =~ s/:([^=:]+)=([^:=\[\]]+)/$hash{$1}=$2,''/eg if ($nhx);
		push(@$stack, \%hash);
		push(@$array, \%hash);
	}
	return $str;
}


1;

__END__
