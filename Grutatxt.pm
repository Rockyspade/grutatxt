#####################################################################
#
#   Grutatxt - A text to HTML (and other things) converter
#
#   Copyright (C) 2000/2003 Angel Ortega <angel@triptico.com>
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#   http://www.triptico.com
#
#####################################################################

package Grutatxt;

use locale;

$VERSION = '2.0.5';

=pod

=head1 NAME

Grutatxt - Text to HTML (and other formats) converter

=head1 SYNOPSIS

 use Grutatxt;

 # create a new Grutatxt converter object
 $grutatxt=new Grutatxt();

 # process a Grutatxt format string
 @output=$grutatxt->process($text);

 # idem for a file
 @output2=$grutatxt->process_file($file);

=head1 DESCRIPTION

Grutatxt is a module to process text documents in
a special markup format (also called Grutatxt), very
similar to plain ASCII text. These documents can be
converted to HTML or troff.

The markup is designed to be fairly intuitive and
straightforward and can include headings, bold and italic
text effects, bulleted, numbered and definition lists, URLs,
function and variable names, preformatted text, horizontal
separators and tables. Special marks can be inserted in the
text and a heading-based structural index can be obtained
from it.

A comprehensive description of the markup is defined in
the README file, included with the Grutatxt package (it is
written in Grutatxt format itself, so it can be converted
using the I<grutatxt> tool to any of the supported formats).
The latest version (and more information) can be retrieved
from the Grutatxt home page at:

 http://www.triptico.com/software/grutatxt.html

=head1 FUNCTIONS AND METHODS

=head2 B<new>

 $grutatxt=new Grutatxt([ "mode"  => $mode, ]
			[ "title" => \$title, ]
			[ "marks" => \@marks, ]
			[ "index" => \@index, ]
			[ "abstract" => \$abstract, ]
			[ "strip-parens" => $bool, ]
			[ "strip-dollars" => $bool, ]
			[ %driver_specific_arguments ] );

Creates a new Grutatxt object instance. All parameters are
optional.

=over 4

=item I<mode>

Output format. Can be HTML or troff. HTML is used if not specified.

=item I<title>

If I<title> is specified as a reference to scalar, the first
level 1 heading found in the text is stored inside it.

=item I<marks>

Marks in the Grutatxt markup are created by inserting the
string <-> alone in a line. If I<marks> is specified as a
reference to array, it will be filled with the subscripts
(relative to the output array) of the lines where the marks
are found in the text.

=item I<index>

If I<index> is specified as a reference to array, it will
be filled with strings in the format

 level,heading

This information can be used to build a table of contents
of the processed text.

=item I<strip-parens>

Function names in the Grutatxt markup are strings of
alphanumeric characters immediately followed by a pair
of open and close parentheses. If this boolean value is
set, function names found in the processed text will have
their parentheses deleted.

=item I<strip-dollars>

Variable names in the Grutatxt markup are strings of
alphanumeric characters preceded by a dollar sign.
If this boolean value is set, variable names found in
the processed text will have the dollar sign deleted.

=item I<abstract>

The I<abstract> of a Grutatxt document is the fragment of text
from the beginning of the document to the end of the first
paragraph after the title. If I<abstract> is specified as a
reference to scalar, it will contain (after each call to the
B<process()> method) the subscript of the element of the output
array that marks the end of the subject.

=back

=cut

sub new
{
	my ($class,%args) = @_;
	my ($gh);

	$args{'mode'} ||= 'HTML';

	$class .= "::" . $args{'mode'};

	$gh = new $class(%args);
			      
	return($gh);
}


=head2 B<process>

 @output=$grutatxt->process($text);

Processes a text in Grutatxt format. The result is returned
as an array of lines.

=cut

sub process
{
	my ($gh,$content) = @_;
	my ($p);

	# clean output
	@{$gh->{'o'}} = ();

	# clean title and paragraph numbers
	$gh->{'-title'} = "";
	$gh->{'-p'} = 0;

	# clean marks
	@{$gh->{'marks'}} = () if ref($gh->{'marks'});

	# clean index
	@{$gh->{'index'}} = () if ref($gh->{'index'});

	# reset abstract line
	${$gh->{'abstract'}} = 0 if ref($gh->{'abstract'});

	# insert prefix
	$gh->_prefix();

	$gh->{'-mode'} = undef;

	foreach my $l (split(/\n/,$content))
	{
		# inline data (passthrough)
		if($l =~ /^<<$/ .. $l =~ /^>>$/)
		{
			$gh->_inline($l);
			next;
		}

		# marks
		if($l =~ /^\s*<\->\s*$/)
		{
			push(@{$gh->{'marks'}},scalar(@{$gh->{'o'}}))
				if ref($gh->{'marks'});

			next;
		}

		# escape possibly dangerous characters
		$l = $gh->_escape($l);

		# empty lines
		$l =~ s/^\r$//ge;
		if($l =~ s/^$/$gh->_empty_line()/ge)
		{
			# mark the abstract end
			if($gh->{'-title'})
			{
				$gh->{'-p'}++;

				# mark abstract if it's the
				# second paragraph from the title
				${$gh->{'abstract'}} = scalar(@{$gh->{'o'}})-1
					if $gh->{'-p'} == 2;
			}
		}

		if($gh->{'-process-urls'})
		{
			# URLs followed by a parenthesized phrase
			$l =~ s/(https?:\/\/\S+)\s+\(([^\)]+)\)/$gh->_url($1,$2)/ge;
			$l =~ s/(ftps?:\/\/\S+)\s+\(([^\)]+)\)/$gh->_url($1,$2)/ge;
			$l =~ s/(file:\/?\S+)\s+\(([^\)]+)\)/$gh->_url($1,$2)/ge;

			# URLs without phrase
			$l =~ s/([^=][^\"])(https?:\/\/\S+)/$1.$gh->_url($2)/ge;
			$l =~ s/([^=][^\"])(ftps?:\/\/\S+)/$1.$gh->_url($2)/ge;
			$l =~ s/([^=][^\"])(file:\/?\S+)/$1.$gh->_url($2)/ge;
			$l =~ s/^(https?:\/\/\S+)/$gh->_url($1)/ge;
			$l =~ s/^(ftps?:\/\/\S+)/$gh->_url($1)/ge;
			$l =~ s/^(file:\/?\S+)/$gh->_url($1)/ge;
		}

		# change '''text''' and *text* into strong emphasis
		$l =~ s/\'\'\'([^\'][^\'][^\']*)\'\'\'/$gh->_strong($1)/ge;
		$l =~ s/\*(\S[^\*]+\S)\*/$gh->_strong($1)/ge;
		$l =~ s/\*(\S+)\*/$gh->_strong($1)/ge;

		# change ''text'' and _text_ into emphasis
		$l =~ s/\'\'([^\'][^\']*)\'\'/$gh->_em($1)/ge;
		$l =~ s/\b_(\S[^_]*\S)_\b/$gh->_em($1)/ge;
		$l =~ s/\b_(\S+)_\b/$gh->_em($1)/ge;

		# enclose function names
		if($gh->{'strip-parens'})
		{
			$l =~ s/(\w+)\(\)/$gh->_funcname($1)/ge;
		}
		else
		{
			$l =~ s/(\w+)\(\)/$gh->_funcname($1."()")/ge;
		}

		# enclose variable names
		if($gh->{'strip-dollars'})
		{
			$l =~ s/\$([\w_\.]+)/$gh->_varname($1)/ge;
		}
		else
		{
			$l =~ s/(\$[\w_\.]+)/$gh->_varname($1)/ge;
		}

		#
		# main switch
		#

		# definition list
		if($l =~ s/^\s\*\s+([\w\s\-\(\)]+)\:\s+/$gh->_dl($1)/e)
		{
		}

		# unsorted list
		elsif($gh->{'-mode'} ne "pre" and
		     ($l =~ s/^(\s+)\*\s+/$gh->_unsorted_list($1)/e or
		      $l =~ s/^(\s+)\-\s+/$gh->_unsorted_list($1)/e))
		{
		}

		# sorted list
		elsif($gh->{'-mode'} ne "pre" and
		     ($l =~ s/^(\s+)\#\s+/$gh->_ordered_list($1)/e or
		      $l =~ s/^(\s+)1\s+/$gh->_ordered_list($1)/e))
		{
		}

		# quoted block
		elsif($l =~ s/^\s\"/$gh->_blockquote()/e)
		{
		}

		# table rows
		elsif($l =~ s/^\s*\|(.*)\|\s*$/$gh->_table_row($1)/e)
		{
		}

		# table heading / end of row
		elsif($l =~ s/^\s*(\+[-\+\|]+\+)\s*$/$gh->_table($1)/e)
		{
		}

		# preformatted text
		elsif($l =~ s/^(\s.*)$/$gh->_pre($1)/e)
		{
		}

		# anything else
		else
		{
			# back to normal mode
			$gh->_new_mode(undef);
		}

		# 1 level heading
		$l =~ s/^(=+)\s*$/$gh->_process_heading(1,$1)/e;

		# 2 level heading
		$l =~ s/^(-+)\s*$/$gh->_process_heading(2,$1)/e;

		# 3 level heading
		$l =~ s/^(~+)\s*$/$gh->_process_heading(3,$1)/e;

		# change ------ into hr
		$l =~ s/^----*$/$gh->_hr()/e;

		# push finally
		$gh->_push($l) if $l;
	}

	# flush
	$gh->_new_mode(undef);

	# postfix
	$gh->_postfix();

	# set title
	${$gh->{'title'}} = $gh->{'-title'} if ref($gh->{'title'});

	# set abstract, if not set
	${$gh->{'abstract'}} = scalar(@{$gh->{'o'}})
		if ref($gh->{'abstract'}) and not ${$gh->{'abstract'}};

	return(@{$gh->{'o'}});
}


=head2 B<process_file>

 @output=$grutatxt->process_file($filename);

Processes a file in Grutatxt format.

=cut

sub process_file
{
	my ($gh,$file) = @_;

	open F, $file or return(undef);

	my ($content) = join('',<F>);
	close F;

	return($gh->process($content));
}


sub _push
{
	my ($gh,$l) = @_;

	push(@{$gh->{'o'}},$l);
}


sub _process_heading
{
	my ($gh,$level,$hd) = @_;
	my ($l);

	$l = pop(@{$gh->{'o'}});

	if($l eq $gh->_empty_line())
	{
		$gh->_push($l);
		return($hd);
	}

	# store title
	$gh->{'-title'} = $l if $level == 1 and not $gh->{'-title'};

	# store index
	if(ref($gh->{'index'}))
	{
		push(@{$gh->{'index'}},"$level,$l");
	}

	return($gh->_heading($level,$l));
}


sub _calc_col_span
{
	my ($gh,$l) = @_;
	my (@spans);

	# strip first + and all -
	$l =~ s/^\+//;
	$l =~ s/-//g;

	my ($t) = 1; @spans = ();
	for(my $n = 0;$n < length($l);$n++)
	{
		if(substr($l,$n,1) eq '+')
		{
			push(@spans,$t);
			$t = 1;
		}
		else
		{
			# it's a colspan mark:
			# increment
			$t++;
		}
	}

	return(@spans);
}


sub _table_row
{
	my ($gh,$str) = @_;

	my @s = split(/\|/,$str);

	for(my $n = 0;$n < scalar(@s);$n++)
	{
		${$gh->{'-table'}}[$n] .= ' ' . $s[$n];
	}

	return("");
}


sub _pre
{
	my ($gh,$l) = @_;

	# if any other mode is active, add to it
	if($gh->{'-mode'} and $gh->{'-mode'} ne "pre")
	{
		$l =~ s/^\s+//;

		my ($a) = pop(@{$gh->{'o'}})." ".$l;
		$gh->_push($a);
		$l = "";
	}
	else
	{
		$gh->_new_mode("pre");
	}

	return($l);
}


sub _multilevel_list
{
	my ($gh, $str, $ind) = @_;
	my (@l,$level);

	@l = @{$gh->{$str}};
	$ind = length($ind);
	$level = 0;

	if($l[-1] < $ind)
	{
		# if last level is less indented, increase
		# nesting level
		push(@l, $ind);
		$level++;
	}
	elsif($l[-1] > $ind)
	{
		# if last level is more indented, decrease
		# levels until the same is found (or back to
		# the beginning if not)
		while(pop(@l))
		{
			$level--;
			last if $l[-1] == $ind;
		}
	}

	$gh->{$str} = \@l;

	return($level);
}


sub _unsorted_list
{
	my ($gh, $ind) = @_;

	return($gh->_ul($gh->_multilevel_list('-ul-levels', $ind)));
}


sub _ordered_list
{
	my ($gh, $ind) = @_;

	return($gh->_ol($gh->_multilevel_list('-ol-levels', $ind)));
}


# empty stubs for falling through the superclass

sub _inline { my ($gh,$l) = @_; $l; }
sub _escape { my ($gh,$l) = @_; $l; }
sub _empty_line { my ($gh) = @_; ""; }
sub _url { my ($gh,$url,$label) = @_; ""; }
sub _strong { my ($gh,$str) = @_; $str; }
sub _em { my ($gh,$str) = @_; $str; }
sub _funcname { my ($gh,$str) = @_; $str; }
sub _varname { my ($gh,$str) = @_; $str; }
sub _new_mode { my ($gh,$mode) = @_; }
sub _dl { my ($gh,$str) = @_; $str; }
sub _ul { my ($gh,$level) = @_; ""; }
sub _ol { my ($gh,$level) = @_; ""; }
sub _blockquote { my ($gh,$str) = @_; $str; }
sub _hr { my ($gh) = @_; "" }
sub _heading { my ($gh,$level,$l) = @_; $l; }
sub _table { my ($gh,$str) = @_; $str; }
sub _prefix { my ($gh) = @_; }
sub _postfix { my ($gh) = @_; }

###########################################################

=head1 DRIVER SPECIFIC INFORMATION

=cut

###########################################################
# HTML Driver

package Grutatxt::HTML;

@ISA = ("Grutatxt");

=head2 HTML Driver

The additional parameters for a new Grutatxt object are:

=over 4

=item I<table-headers>

If this boolean value is set, the first row in tables
is assumed to be the heading and rendered using <th>
instead of <td> tags.

=item I<center-tables>

If this boolean value is set, tables are centered.

=item I<expand-tables>

If this boolean value is set, tables are expanded (width 100%).

=item I<dl-as-dl>

If this boolean value is set, definition lists will be
rendered using <dl>, <dt> and <dd> instead of tables.

=item I<header-offset>

Offset to be summed to the heading level when rendering
<h?> tags (default is 0).

=item I<class-oddeven>

If this boolean value is set, tables will be rendered
with an "oddeven" CSS class, and rows alternately classed
as "even" or "odd". If it's not set, no CSS class info
is added to tables.

=back

=cut

sub new
{
	my ($class,%args) = @_;
	my ($gh);

	bless(\%args,$class);
	$gh = \%args;

	$gh->{'-process-urls'} = 1;

	return($gh);
}


sub _inline
{
	my ($gh,$l) = @_;

	# accept unnamed and HTML inlines
	if($l =~ /^<<$/ or $l =~ /^<<\s*html$/i)
	{
		$gh->{'-inline'} = "HTML";
		return;
	}

	if($l =~ /^>>$/)
	{
		delete $gh->{'-inline'};
		return;
	}

	if($gh->{'-inline'} eq "HTML")
	{
		$gh->_push($l);
	}
}


sub _escape
{
	my ($gh,$l) = @_;

	$l =~ s/&/&amp;/g;
	$l =~ s/</&lt;/g;
	$l =~ s/>/&gt;/g;

	return($l);
}


sub _empty_line
{
	my ($gh) = @_;

	return("<p>");
}


sub _url
{
	my ($gh,$url,$label) = @_;

	$label = $url unless $label;

	return("<a href=\"$url\">$label</a>");
}


sub _strong
{
	my ($gh,$str) = @_;
	return("<strong class=strong>$str</strong>");
}


sub _em
{
	my ($gh,$str) = @_;
	return("<em class=em>$str</em>");
}


sub _funcname
{
	my ($gh,$str) = @_;
	return("<code class=funcname>$str</code>");
}


sub _varname
{
	my ($gh,$str) = @_;
	return("<code class=var>$str</code>");
}


sub _new_mode
{
	my ($gh,$mode,$params) = @_;

	if($mode ne $gh->{'-mode'})
	{
		my $tag;

		# flush previous mode

		# clean list levels
		if($gh->{'-mode'} eq "ul")
		{
			$gh->_push("</ul>" x scalar(@{$gh->{'-ul-levels'}}));
		}
		elsif($gh->{'-mode'} eq "ol")
		{
			$gh->_push("</ol>" x scalar(@{$gh->{'-ol-levels'}}));
		}
		elsif($gh->{'-mode'})
		{
			$gh->_push("</$gh->{'-mode'}>");
		}

		# send new one
		$tag = $params ? "<$mode $params>" : "<$mode>";
		$gh->_push($tag) if $mode;

		$gh->{'-mode'} = $mode;

		# clean previous lists
		$gh->{'-ul-levels'} = undef;
		$gh->{'-ol-levels'} = undef;
	}
}


sub _dl
{
	my ($gh,$str) = @_;

	if($gh->{'dl-as-dl'})
	{
		$gh->_new_mode("dl");
		return("<dt><strong class=term>$str</strong><dd>");
	}
	else
	{
		$gh->_new_mode("table");
		return("<tr><td valign=top><strong class=term>$1</strong>&nbsp;&nbsp;</td><td valign=top>");
	}
}


sub _ul
{
	my ($gh, $levels) = @_;
	my ($ret);

	$ret = "";

	if($levels > 0)
	{
		$ret = "<ul>";
	}
	elsif($levels < 0)
	{
		$ret = "</ul>" x abs($levels);
	}

	$gh->{'-mode'} = "ul";

	$ret .= "<li>";

	return($ret);
}


sub _ol
{
	my ($gh, $levels) = @_;
	my ($ret);

	$ret = "";

	if($levels > 0)
	{
		$ret = "<ol>";
	}
	elsif($levels < 0)
	{
		$ret = "</ol>" x abs($levels);
	}

	$gh->{'-mode'} = "ol";

	$ret .= "<li>";

	return($ret);
}


sub _blockquote
{
	my ($gh) = @_;

	$gh->_new_mode("blockquote");
	return("\"");
}


sub _hr
{
	my ($gh) = @_;

	return("<hr size=1 noshade>");
}


sub _heading
{
	my ($gh,$level,$l) = @_;

	# substitute anchor spaces with underscores
	my ($a) = lc($l); $a =~ s/\s/_/g;

	$l = sprintf("<a name=\"%s\"></a>\n<h%d class=level$level>%s</h%d>",
		$a, $level+$gh->{'header-offset'},
		$l, $level+$gh->{'header-offset'});

	return($l);
}


sub _table
{
	my ($gh,$str) = @_;

	if($gh->{'-mode'} eq "table")
	{
		my ($class) = "";
		my (@spans) = $gh->_calc_col_span($str);

		# calculate CSS class, if any
		if($gh->{'class-oddeven'})
		{
			$class = ($gh->{'-tbl-row'} & 1) ? "odd" : "even";
		}

		$str = "<tr $class>";

		# build columns
		for(my $n = 0;$n < scalar(@{$gh->{'-table'}});$n++)
		{
			my ($i,$s);

			$i = ${$gh->{'-table'}}[$n];
			$i = "&nbsp;" if $i =~ /^\s*$/;

			$s = " colspan=$spans[$n]" if $spans[$n] > 1;

			if($gh->{'table-headers'} and $gh->{'-tbl-row'} == 1)
			{
				$str .= "<th $class $s>$i</th>";
			}
			else
			{
				$str .= "<td $class $s>$i</td>";
			}
		}

		@{$gh->{'-table'}} = ();
		$gh->{'-tbl-row'}++;
	}
	else
	{
		# new table
		my ($params);

		$params = "border=1";
		$params .= " width='100\%'" if $gh->{'expand-tables'};
		$params .= " align=center" if $gh->{'center-tables'};
		$params .= " class=oddeven" if $gh->{'class-oddeven'};

		$gh->_new_mode("table", $params);

		@{$gh->{'-table'}} = ();
		$gh->{'-tbl-row'} = 1;
		$str = "";
	}

	return($str);
}


###########################################################
# troff Driver

package Grutatxt::troff;

@ISA = ("Grutatxt");

=head2 troff Driver

The troff driver uses the B<-me> macros and B<tbl>. A
good way to post-process this output (to PostScript in
the example) could be by using

 groff -t -me -Tps

The additional parameters for a new Grutatxt object are:

=over 4

=item I<normal-size>

The point size of normal text. By default is 10.

=item I<heading-sizes>

This argument must be a reference to an array containing
the size in points of the 3 different heading levels. By
default, level sizes are [ 20, 18, 15 ].

=item I<table-type>

The type of table to be rendered by B<tbl>. Can be
I<allbox> (all lines rendered; this is the default value),
I<box> (only outlined) or I<doublebox> (only outlined by
a double line).

=back

=cut

sub new
{
	my ($class,%args) = @_;
	my ($gh);

	bless(\%args,$class);
	$gh = \%args;

	$gh->{'-process-urls'} = 0;

	$gh->{'heading-sizes'} ||= [ 20, 18, 15 ];
	$gh->{'normal-size'} ||= 10;
	$gh->{'table-type'} ||= "allbox"; # box, allbox, doublebox

	return($gh);
}


sub _prefix
{
	my ($gh) = @_;

	$gh->_push(".nr pp $gh->{'normal-size'}");
	$gh->_push(".nh");
}


sub _inline
{
	my ($gh,$l) = @_;

	# accept only troff inlines
	if($l =~ /^<<\s*troff$/i)
	{
		$gh->{'-inline'} = "troff";
		return;
	}

	if($l =~ /^>>$/)
	{
		delete $gh->{'-inline'};
		return;
	}

	if($gh->{'-inline'} eq "troff")
	{
		$gh->_push($l);
	}
}


sub _escape
{
	my ($gh,$l) = @_;

	$l =~ s/\\/\\\\/g;
	$l =~ s/^'/\\&'/;

	return($l);
}


sub _empty_line
{
	my ($gh) = @_;

	return(".lp");
}


sub _strong
{
	my ($gh,$str) = @_;
	return("\\fB$str\\fP");
}


sub _em
{
	my ($gh,$str) = @_;
	return("\\fI$str\\fP");
}


sub _funcname
{
	my ($gh,$str) = @_;
	return("\\fB$str\\fP");
}


sub _varname
{
	my ($gh,$str) = @_;
	return("\\fI$str\\fP");
}


sub _new_mode
{
	my ($gh,$mode,$params) = @_;

	if($mode ne $gh->{'-mode'})
	{
		my $tag;

		# flush previous list
		if($gh->{'-mode'} eq "pre")
		{
			$gh->_push(".)l");
		}
		elsif($gh->{'-mode'} eq "table")
		{
			chomp($gh->{'-table-head'});
			$gh->{'-table-head'} =~ s/\s+$//;
			$gh->_push($gh->{'-table-head'} . ".");
			$gh->_push($gh->{'-table-body'} . ".TE\n.sp 0.6");
		}
		elsif($gh->{'-mode'} eq "blockquote")
		{
			$gh->_push(".)q");
		}

		# send new one
		if($mode eq "pre")
		{
			$gh->_push(".(l L");
		}
		elsif($mode eq "blockquote")
		{
			$gh->_push(".(q");
		}

		$gh->{'-mode'} = $mode;
	}
}


sub _dl
{
	my ($gh,$str) = @_;

	$gh->_new_mode("dl");
	return(".ip \"$str\"\n");
}


sub _ul
{
	my ($gh) = @_;

	$gh->_new_mode("ul");
	return(".bu\n");
}


sub _ol
{
	my ($gh) = @_;

	$gh->_new_mode("ol");
	return(".np\n");
}


sub _blockquote
{
	my ($gh) = @_;

	$gh->_new_mode("blockquote");
	return("\"");
}


sub _hr
{
	my ($gh) = @_;

	return(".hl");
}


sub _heading
{
	my ($gh,$level,$l) = @_;

	$l = ".sz " . ${$gh->{'heading-sizes'}}[$level - 1] . "\n$l\n.sp 0.6";

	return($l);
}


sub _table
{
	my ($gh,$str) = @_;

	if($gh->{'-mode'} eq "table")
	{
		my ($h,$b);
		my (@spans) = $gh->_calc_col_span($str);

		# build columns
		$h = "";
		$b = "";
		for(my $n = 0;$n < scalar(@{$gh->{'-table'}});$n++)
		{
			my ($i);

			if($gh->{'table-headers'} and $gh->{'-tbl-row'} == 1)
			{
				$h .= "cB ";
			}
			else
			{
				$h .= "l ";
			}

			# add span columns
			$h .= "s " x ($spans[$n] - 1) if $spans[$n] > 1;

			$b .= "#" if $n;

			$i = ${$gh->{'-table'}}[$n];
			$i =~ s/^\s+//;
			$i =~ s/\s+$//;
			$i =~ s/(\s)+/$1/g;
			$b .= $i;
		}

		# add a separator
		$b .= "\n_" if $gh->{'table-headers'} and
			     $gh->{'-tbl-row'} == 1 and
			     $gh->{'table-type'} ne "allbox";

		$gh->{'-table-head'} .= "$h\n";
		$gh->{'-table-body'} .= "$b\n";

		@{$gh->{'-table'}} = ();
		$gh->{'-tbl-row'}++;
	}
	else
	{
		# new table
		$gh->_new_mode("table");

		@{$gh->{'-table'}} = ();
		$gh->{'-tbl-row'} = 1;

		$gh->{'-table-head'} = ".TS\n$gh->{'table-type'} tab (#);\n";
		$gh->{'-table-body'} = "";
	}

	$str = "";
	return($str);
}


sub _postfix
{
	my ($gh) = @_;

	# add to top headings and footers
	unshift(@{$gh->{'o'}},".ef '\%' ''");
	unshift(@{$gh->{'o'}},".of '' '\%'");
	unshift(@{$gh->{'o'}},".eh '$gh->{'-title'}' ''");
	unshift(@{$gh->{'o'}},".oh '' '$gh->{'-title'}'");
}


=head1 AUTHOR

Angel Ortega angel@triptico.com

=cut

1;
