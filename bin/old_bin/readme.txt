Tree包是在FGF项目(http://fgf.genomics.org.cn)时积淀下来的，nhx.pm是从Treefam项目继承下来的，增加了一些简单功能和注释；nhx_svg.pm也源于Treefam项目，只是把画png图的方法翻译成了SVG,并做了一些改进和注释；nhx_align_svg.pm是专门为FGF项目作图时开发的。

这三个模块是依次继承的关系：nhx.pm用于分解nhx格式的进化树文件，在内存中形成树的双向链表结构；nhx_svg.pm继承了nhx.pm，同时利用SVG包绘制树的结构图；nhx_align_svg.pm继承了nhx_svg.pm，不仅绘制树的结构图，还绘制基因的exon-intron结构。

draw_tree.pl 是画一般进化树图形的示例程序，结果是tree.svg
draw_GDAP.pl 是画FGF图形的示例程序，结果是GDAP.svg

