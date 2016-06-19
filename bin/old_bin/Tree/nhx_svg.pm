## draw SVG tree figure with nh or nhx text format
## Creat on: 2006-3-28
package Tree::nhx_svg;
use strict;
use SVG;
use SVG::Font;
use Tree::nhx;
use vars qw(@ISA);
@ISA = qw(Tree::nhx);


## creat a new obejct, and set the parameters
sub new
{	
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = Tree::nhx->new(
		_node=>undef,				_root=>undef,
		_n_leaf=>undef,				_error=>undef,
							
		tree_dist=>0,				tree_width=>0,			
		width=>640,					height=>480, 
		left_margin=>60,			right_margin=>60,
		top_margin=>40,				bottom_margin=>40,
		skip=>40,					is_real=>1,
		half_box=>3,				c_node=>"#0000FF",
		line_width=>1,				c_line=>"#00FF00",
		font=>'Times-Bold',			fsize=>12,
		c_bg=>"#FFFFFF",			c_frame=>"#FF00CC", 
		c_inter=>"#FF6600",			c_exter=>"#000000",
		c_status=>"#FF0000",		c_W=>"#FF00CC",
		c_B=>"#330099",				show_B=>0,
		show_inter=>0,				show_exter=>1,
		show_ruler=>0,				show_W=>0,
		show_frame=>0,				view_cut=>1,
		show_groupKaKs=>0,          groupKaKs_significance=>0.05,
		exter_include=>0,			_svg=>'',
		show_legend=>0,				legend_height=>80,
		@_ );
	
	bless($self, $class);
	return $self;
}

##text width and text height caculation
#$swdith = textWidth($font_family,$font_size,$str);
#$sheight = textHeight($font_size);

##caculate logical X,Y(大写) of each node
##整棵树的纵向距离设为 1 ,最上节点Y为0，每个向下叶节点逐渐加1，最后都除以(叶节点个数-1)。
##无论真枝长还是均枝长，树横向总距离都是 1；
sub cal_XY
{
	my $self = shift;
	my ($i, $j, $scale);
	my $is_real = $self->{is_real};
	my $array = $self->{_node};
	
	##循环 数组@{$self->{_node}}一次, 即按左右中顺序遍历整个树一遍。
	
	if ($self->{_n_leaf} == 1) {
		foreach my $p (@$array) {
			$p->{X} = 0;
			$p->{Y} = 0;
		}
		return;
	}

	#caculate Y
	$j = 0;
	$scale = $self->{_n_leaf} - 1; #$scale shoule plus 1，change by Fanwei
	foreach my $p (@$array) {
		$p->{Y} = ($p->{C})? ($p->{C}[0]->{Y} + $p->{C}[@{$p->{C}}-1]->{Y}) / 2.0 : ($j++) / $scale;
	}
	
	my $add_dist;
	foreach my $p (@$array) {
		$add_dist += $p->{dist};
	}
	$is_real = 0 if(!$add_dist);

	#calculate X
	if ($is_real) {		
		##根节点如果有dist则使用，否则根节点X设置为0, 此处$scale为整棵树X方向上最大的逻辑长度 
		$scale = $$self{_root}{X} = (defined($$self{_root}{dist}) && $$self{_root}{dist} > 0.0)? $$self{_root}{dist} : 0.0;
		for (my $i = @$array - 2; $i >= 0; --$i) {
			my $p = $array->[$i];
			$p->{X} = $p->{P}->{X} + (($p->{dist} >= 0.0)? $p->{dist} : 0.0);
			$scale = $p->{X} if ($p->{X} > $scale);
		}
	} else {
		##如不使用真枝长， 根节点处X设置为 0， 然后逐级 加 1
		$scale = $$self{_root}{X} = 0.0; ##changed by FanWei
		for (my $i = @$array - 2; $i >= 0; --$i) {
			my $p = $array->[$i];
			$p->{X} = $p->{P}->{X} + 1.0;
			$scale = $p->{X} if ($p->{X} > $scale);
		}
		
		##使所有叶节点X相同，显示在同一条纵线上。
		foreach my $p (@$array) {
			$p->{X} = $scale unless ($p->{C});
		}
	}
	
	##无论真枝长还是均枝长，都是最大X变为1
	foreach my $p (@$array) {	
		$p->{X} /= $scale;
	}
	$self->{tree_dist} = $scale;
}


## caculate 像素坐标 x， y（小写）
sub cal_xy{
	my $self = shift;
	$self->cal_XY;

	## get max length of name space 
	my $max = 0; # the max length of leaf names
	my $array = $self->{_node};
	foreach my $p (@$array) {
		my $tw = textWidth($self->{font},$self->{fsize},$p->{N});
		$max = $tw if (!$p->{C} && $tw > $max);
	}

	## 当skip非零时，图像高度height由叶节点个数决定，否则为指定的height值，而width则只能指定。
	if ($self->{skip}){
		$self->{height} = $self->{top_margin} + $self->{bottom_margin} + $self->{skip} * ($self->{_n_leaf}-1);
		$self->{height} += $self->{skip} if($self->{show_ruler});
		$self->{height} += $self->{legend_height} if(exists $self->{show_legend} && $self->{legend_height} > 0);
	}
	
	
	## 树的像素宽度，像素高度，树原点与图像原点之间的x差，树原点与图像原点之间的y差
	my ($real_x, $real_y, $shift_x, $shift_y);
	
	$real_x = $self->{width} - $self->{left_margin} - $self->{right_margin} ;
	$real_x -=  $max if($self->{exter_include});
	$real_y = $self->{height} - $self->{top_margin} - $self->{bottom_margin}  - textHeight($self->{fsize}) ;
	$real_y -= $self->{skip} if($self->{show_ruler});
	$real_y -= $self->{legend_height} if($self->{show_legend});
	$shift_x = $self->{left_margin};  
	$shift_y = $self->{top_margin} + textHeight($self->{fsize}) / 2; 

	my $half = $self->{half_box}; 
	foreach my $p (@$array) {
		
		## 逻辑坐标X和Y的最大值都是1，此处计算实际像素坐标x和y，加0.5四舍五入，int只返回整数部分
		$p->{x} = int($p->{X} * $real_x + $shift_x + 0.5);
		$p->{y} = int($p->{Y} * $real_y + $shift_y + 0.5);
		
		## 计算所有节点矩形区域坐标，used for web information mapping
		#@{$p->{node_area}} = ($p->{x}-$half, $p->{y}-$half, $p->{x}+$half, $p->{y}+$half);
		#next if ($p->{C});
		
		#计算叶节点名字区域坐标，used for web information mapping
		#@{$p->{area}} = ($p->{x}+$self->{half_box}+3,
		#	$p->{y}-textHeight($self->{fsize})/2,
		#	$p->{x}+$self->{half_box}+3+textWidth($self->{font},$self->{fsize},$p->{N}),
		#	$p->{y}+textHeight($self->{fsize})/2);
	}
	$self->{tree_width} = $real_x;
}


## draw ruler for tree branches and exon blocks
sub plot_ruler{
	my ($self,$Y,$X_start,$X_end,$len,$type) = @_ ;
	my $svg = $self->{_svg};
	my $scale_size = 6;
	
	## draw the main axis
	$svg->line('x1',$X_start,'y1',$Y,'x2',$X_end,'y2',$Y,'stroke','#000000','stroke-width',1);		
	return if($len == 0);
	
	$svg->text('x',$X_start-textWidth($self->{font},$self->{fsize},$type)-5,'y',$Y,'-cdata',$type,"font-family",$self->{font},"font-size",$self->{fsize},"fill",'#000000');
	my ($divid,$str,$str1,$str2,$unit);
	$divid = 5;
	$str = $len / $divid;
	$str = sprintf("%e",$str);
	if ($str=~/([\d\.]+)e([+-\d]+)/) {
		$str1 = $1;
		$str2 = $2;
	}
	$str1 = int ( $str1 + 0.5 );
	$unit = $str1 * 10 ** $str2;
	
	## draw small scale lines
	for (my $i=0; $i<=$len; $i+=$unit/5) {
		
		my $X = $X_start + $i / $len * ($X_end - $X_start);
		$svg->line('x1',$X,'y1',$Y - $scale_size/2,'x2',$X,'y2',$Y,'stroke','#000000','stroke-width',1);
	}
	
	## draw big scales lines and texts 
	for (my $i=0; $i<=$len; $i+=$unit) {
		my $X = $X_start + $i / $len * ($X_end - $X_start);
		$svg->line('x1',$X,'y1',$Y - $scale_size,'x2',$X,'y2',$Y,'stroke','#000000','stroke-width',1);
		$svg->text('x',$X - textWidth($self->{font},$self->{fsize},$i) / 2,'y',$Y+textHeight($self->{fsize})+4,'fill','#000000','-cdata',$i,'font-size',$self->{fsize}, 'font-family',$self->{font});
	}

}

## draw status mark
sub draw_status{
	my ($self,$x,$y,$r) = @_ ;
	my $CIR = 2 * 3.1415926;
	my $svg = $self->{_svg};
	$svg->polygon('points',
	[
	$x,$y-$r,
	$x + $r * cos(2*$CIR/5-$CIR/4), $y + $r * sin(2*$CIR/5-$CIR/4),
	$x - $r * cos($CIR/4-$CIR/5), $y - $r * sin($CIR/4-$CIR/5),
	$x + $r * cos($CIR/4-$CIR/5), $y - $r * sin($CIR/4-$CIR/5),
	$x - $r * cos(2*$CIR/5-$CIR/4), $y + $r * sin(2*$CIR/5-$CIR/4)
	],
	'fill','red');
	
}


## draw legend
sub draw_tree_legend{
	my $self = shift;
	my $svg = $self->{_svg};
	my $legend_y = $self->{height} - $self->{bottom_margin} - $self->{legend_height} + 30;
	my $horizontal_shift = 130;
	my $vertical_shift = 20;
	
	my ($x,$y) = ($self->{left_margin},$legend_y);
	$svg->rect('x',$x, 'y',$y,'width',$self->{half_box}*2,'height',$self->{half_box}*2,'fill',$self->{c_node});
	$svg->text('x',$x+30,'y',$y+$self->{half_box}*2,'-cdata','Node', 'font-size',$self->{fsize}, 'font-family',$self->{font});
	
	$y += $vertical_shift;
	$svg->line('x1',$x,'y1',$y,'x2',$x+20,'y2',$y,'stroke',$self->{c_line},'stroke-width',$self->{line_width});
	$svg->text('x',$x+30,'y',$y+$self->{half_box}*2,'-cdata','Branch','font-size',$self->{fsize}, 'font-family',$self->{font});
	
	$x += $horizontal_shift;
	$y -= $vertical_shift;
	$svg->text('x',$x,'y',$y+$self->{half_box}*2,'-cdata','float','font-size',$self->{fsize}, 'font-family',$self->{font},"fill",$self->{c_W});
	$svg->text('x',$x+40,'y',$y+$self->{half_box}*2,'-cdata','Ka/Ks ratio','font-size',$self->{fsize}, 'font-family',$self->{font});

	
	$y += $vertical_shift;
	$svg->text('x',$x,'y',$y+$self->{half_box}*2,'-cdata','int','font-size',$self->{fsize}, 'font-family',$self->{font},"fill",$self->{c_B});
	$svg->text('x',$x+40,'y',$y+$self->{half_box}*2,'-cdata','Bootstrap','font-size',$self->{fsize}, 'font-family',$self->{font});

	$x += $horizontal_shift;
	$y -= $vertical_shift;
	$svg->text('x',$x,'y',$y+$self->{half_box}*2,'-cdata','text','font-size',$self->{fsize}, 'font-family',$self->{font},"fill",$self->{c_exter});
	$svg->text('x',$x+40,'y',$y+$self->{half_box}*2,'-cdata','Paralog ID','font-size',$self->{fsize}, 'font-family',$self->{font});

	
	$y += $vertical_shift;
	$svg->text('x',$x+40,'y',$y+$self->{half_box}*2,'-cdata','Best hit','font-size',$self->{fsize}, 'font-family',$self->{font});
	my $CIR = 2 * 3.1415926;
	my $r = 7;
	$x += 7;
	$y += 3;
	my $svg = $self->{_svg};
	$svg->polygon('points',
	[
	$x,$y-$r,
	$x + $r * cos(2*$CIR/5-$CIR/4), $y + $r * sin(2*$CIR/5-$CIR/4),
	$x - $r * cos($CIR/4-$CIR/5), $y - $r * sin($CIR/4-$CIR/5),
	$x + $r * cos($CIR/4-$CIR/5), $y - $r * sin($CIR/4-$CIR/5),
	$x - $r * cos(2*$CIR/5-$CIR/4), $y + $r * sin(2*$CIR/5-$CIR/4)
	],
	'fill','red');

}



sub plot_core{
	my $self = shift;
	$self->cal_xy;
	my $array = $self->{_node};
	
	my ($view_width,$view_height) = ($self->{view_cut}) ? ($self->{width},$self->{height}) : (10000,10000);

	my $svg = SVG->new('width',$view_width,'height',$view_height);
	$self->{_svg} = $svg;
	
	## set backgroud color, and draw a frame for the whole figure
	$svg->rect('x',0, 'y',0,'width',$self->{width},'height',$self->{height},'fill',$self->{c_bg});
	$svg->rect('x',0, 'y',0,'width',$self->{width}-1,'height',$self->{height}-1,'stroke',$self->{c_frame},'fill','none') if($self->{show_frame});

	
	
	# draw external node names
	foreach my $p (@$array) {
		if($self->{show_exter} && !$p->{C} && $p->{N}) {
			#my $color = (defined $p->{status} && $p->{status} == 1) ? $self->{c_status} : $self->{c_exter} ;
			my $outname = (defined $p->{replace}) ? $p->{replace} : $p->{N};
			
			$svg->text('x',$p->{x}+$self->{half_box}+4,'y',$p->{y}+textHeight($self->{fsize})/2,'fill',$self->{c_exter},'-cdata',$outname,'font-size',$self->{fsize}, 'font-family',$self->{font});
		}
	}
	
	# draw internal node names
	foreach my $p (@$array) {
		if ($self->{show_inter} && $p->{C} && $p->{N}){
			$svg->text('x',$p->{x}-textWidth($self->{font},$self->{fsize},$p->{N})-$self->{half_box}-2,'y',$p->{y}-2,'fill',$self->{c_inter},'-cdata',$p->{N},'font-size',$self->{fsize}, 'font-family',$self->{font});
		}	
	}
	
	# draw horizontal lines, 如果根节点处为二叉树,则画一短线以示为有根的树
	if( $self->root->{C} && @{$$self{_root}{C}} == 2 ){
		$svg->line('x1',$self->{left_margin}/2,'y1',$$self{_root}{y},'x2',$$self{_root}{x},'y2',$$self{_root}{y},'stroke',$self->{c_line},'stroke-width',$self->{line_width});
	}
	foreach my $p (@$array) {
		if ($p != $self->{_root}){
			$svg->line('x1',$p->{x},'y1',$p->{y},'x2',$p->{P}->{x},'y2',$p->{y},'stroke',$self->{c_line},'stroke-width',$self->{line_width});		
		}
	}
	
	# draw vertical lines
	foreach my $p (@$array) {
		if ($p->{C}){
			$svg->line('x1',$p->{x},'y1',$p->{C}[0]->{y},'x2',$p->{x},'y2',$p->{C}[@{$p->{C}}-1]->{y},'stroke',$self->{c_line},'stroke-width',$self->{line_width});		
		}
	}
	
	# draw rectangle nodes 
	foreach my $p (@$array) {
		if($p->{status} != 1){
			$svg->rect('x',$p->{x}-$self->{half_box}, 'y',$p->{y}-$self->{half_box},'width',$self->{half_box}*2,'height',$self->{half_box}*2,'fill',$self->{c_node});
		}else{##画一个五角星
			$self->draw_status($p->{x}-$self->{half_box},$p->{y}-$self->{half_box}+2,7);
		}
	}

	
	
	## draw ruler
	my $ruler_y = $self->{height} - $self->{bottom_margin};
	$ruler_y -= $self->{legend_height} if($self->{show_legend});
	$self->plot_ruler( $ruler_y,$self->{left_margin}, $self->{left_margin} + $self->{tree_width}, $self->{tree_dist}, "dn" ) if($self->{show_ruler} && $self->{tree_width} );
	
	$self->draw_tree_legend() if($self->{show_legend});
	
	## draw tag of Ka/Ks
	foreach my $p (@$array) {
		if($self->{show_W} && defined $p->{W}) {
			my $str = $p->{W};
			$str = sprintf("%.2f",$p->{W}) if($str !~ /\$/ && $str !~ /-/ && $str < 100);
			$str = "large" if($str >= 100);
			$str = "none" if($str =~ /\$/ || $str =~ /-/);
			
			my $sw = textWidth($self->{font},$self->{fsize},$str);
			my $x = ($p->{x} - $self->{half_box} - $p->{P}->{x}  >= $sw) ? ($p->{P}->{x} + $p->{x} - $self->{half_box} - $sw)/2 : ($p->{x} - $self->{half_box} - $sw ) ;
			$svg->text('x',$x,'y',$p->{y}-4,'fill',$self->{c_W},'-cdata',$str,'font-size',$self->{fsize}, 'font-family',$self->{font});
				
		}
	}
	
	## draw tag of B (B)
	foreach my $p (@$array) {
		next if($p eq $self->root && $p->{B} == 0);
		if($self->{show_B}  && defined $p->{B}) {
			my $str = sprintf("%d",$p->{B});
			my $sw = textWidth($self->{font},$self->{fsize},$str);
			my $x = ($p->{x} - $self->{half_box} - $p->{P}->{x}  >= $sw) ? ($p->{P}->{x} + $p->{x} - $self->{half_box} - $sw)/2 : ($p->{x} - $self->{half_box} - $sw ) ;
			$x = $p->{x} - $self->{half_box} - $sw - 5 if($p eq $self->root);
			$svg->text('x',$x,'y',$p->{y}+textHeight($self->{fsize})+4,'fill',$self->{c_B},'-cdata',$str,'font-size',$self->{fsize}, 'font-family',$self->{font});
				
		}
	}

	##draw group KaKs, show result directly on the figure
#	foreach my $p (@$array) {
#		if ($self->{show_groupKaKs}){
#			my $group_color = "black";
#			my $font_height = textHeight($self->{fsize}) * 1.3;
#			
#			my $vertical_coor = $p->{y} - $font_height;
#			if(defined $p->{RootLeftW} && $p->{RootLeftP} < $self->{groupKaKs_significance}){
#				my $str = "RoLe:W=$p->{RootLeftW};P=$p->{RootLeftP};";
#				$svg->text('x',$p->{x},'y',$vertical_coor,'fill',$group_color,'-cdata',$str,'font-size',$self->{fsize}, 'font-family',$self->{font});
#			}
#			$vertical_coor += $font_height;
#			if(defined $p->{RootRightW} && $p->{RootRightP} < $self->{groupKaKs_significance}){
#				my $str = "RoRi:W=$p->{RootRightW};P=$p->{RootRightP};";
#				$svg->text('x',$p->{x},'y',$vertical_coor,'fill',$group_color,'-cdata',$str,'font-size',$self->{fsize}, 'font-family',$self->{font});
#			}
#			$vertical_coor += $font_height;
#			if(defined $p->{LeftRightW} && $p->{LeftRightP} < $self->{groupKaKs_significance}){
#				my $str = "LeRi:W=$p->{LeftRightW};P=$p->{LeftRightP};\n";
#				$svg->text('x',$p->{x},'y',$vertical_coor,'fill',$group_color,'-cdata',$str,'font-size',$self->{fsize}, 'font-family',$self->{font});
#			}
#			$vertical_coor += $font_height;
#
#		}	
#	}

	##draw group KaKs, show result by pop box，anchor to inner name
	##将全套mark改称node
	foreach my $p (@$array) {
		if ($self->{show_groupKaKs}){
			my ($group_color,$group_str);
			
			$group_color = "black";
			$group_str = "Name: ".$p->{N}."\\n" if(defined $p->{N});

			if(defined $p->{RootLeftW}){
				$group_str .= "Root Vs Left: W=$p->{RootLeftW}; ";
				$group_str .= "P=$p->{RootLeftP}; " if(defined $p->{RootLeftP});
				$group_str .= "\\n";
				$group_color = "red" if(defined $p->{RootLeftP} && $p->{RootLeftP} < $self->{groupKaKs_significance});
			}
			if(defined $p->{RootRightW} ){
				$group_str .= "Root Vs Right: W=$p->{RootRightW}; ";
				$group_str .= "P=$p->{RootRightP}; " if(defined $p->{RootRightP});
				$group_str .= "\\n";
				$group_color = "red" if(defined $p->{RootRightP} && $p->{RootRightP} < $self->{groupKaKs_significance});
			}
			if(defined $p->{LeftRightW}){
				$group_str .= "Left Vs Right: W=$p->{LeftRightW}; ";	
				$group_str .= "P=$p->{LeftRightP}; " if(defined $p->{LeftRightP});
				$group_str .= "\\n";
				$group_color = "red" if(defined $p->{LeftRightP} && $p->{LeftRightP} < $self->{groupKaKs_significance});
			}
						
			##onclick="alert('x:5\ny:5')" onmousemove="window.status='x:5\ty:5'"
			if (defined $p->{C} && defined $p->{N}){
				$svg->text('x',$p->{x}-textWidth($self->{font},$self->{fsize},$p->{N})-$self->{half_box}-2,'y',$p->{y}-2,'fill',$group_color,'-cdata',$p->{N},'font-size',$self->{fsize}, 'font-family',$self->{font}, 'onclick', "alert('$group_str')");
			}	
		}	
	}


}




## 绘制进化树树的图
sub plot{
	my $self = shift;
	$self->plot_core();	
	my $out = $self->{_svg}->xmlify();
	##$out =~ s/<!DOCTYPE.+?>//s;
	##$out =~ s/\s+xmlns=.+?>/>/s;
	##$out =~ s/<!--.+?-->//s;
	return $out;

}

1;

__END__

