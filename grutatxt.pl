###########################################
#
# Grutatxt Main Text2HTML conversion
#
###########################################
# -*- Mode: Perl

use locale;

# version 0.7.6

sub grutatxt
# gruta text to html conversion
{
	my ($content,%opts)=@_;
	my ($pre,$lt,@g);
	my ($tbl,@tbl,$tblo,$inline);

	$pre=0; $lt=''; $tbl=0; $tblo=0; $inline=0;

	foreach my $l (split(/\n/,$content))
	{
		# inline HTML
		if($inline)
		{
			if($l =~ /^>>$/)
			{
				$inline=0;
			}
			else
			{
				push(@g,$l);
			}

			next;
		}
		else
		{
			if($l =~ /^<<$/)
			{
				$inline=1;
				next;
			}
		}

		# strip HTML
		$l =~ s/&/&amp;/g;
		$l =~ s/</&lt;/g;
		$l =~ s/>/&gt;/g;

		# convert empty lines into paragraph delimiters
		$l =~ s/^$/<p>/g;
		$l =~ s/^\r$/<p>/g;

		# links followed by words in parentheses
		$l =~ s/(http:\/\/[\w\/\.\?\&\=\-\%]*)\s*\(([^\)]+)\)/<a href="$1">$2<\/a>/g;

		# make links clickable
		$l =~ s/([^=][^\"])(http:\/\/[\w\/\.\?\&\=\-\%]*)/$1<a href="$2">$2<\/a>/g;
		$l =~ s/^(http:\/\/[\w\/\.\?\&\=\-\%]*)/<a href="$1">$1<\/a>/g;

		# change '''text''' and *text* into bold
		$l =~ s/\'\'\'([^\'][^\'][^\']*)\'\'\'/<strong class=strong>$1<\/strong>/g;
		$l =~ s/\*(\S[^\*]+\S)\*/<strong class=strong>$1<\/strong>/g;
		$l =~ s/\*(\S+)\*/<strong class=strong>$1<\/strong>/g;

		# change ''text'' and _text_ into cursive
		$l =~ s/\'\'([^\'][^\']*)\'\'/<em class=em>$1<\/em>/g;
		$l =~ s/\b_(\S[^_]*\S)_\b/<em class=em>$1<\/em>/g;
		$l =~ s/\b_(\S+)_\b/<em class=em>$1<\/em>/g;

		# enclose function names
		if($opts{'strip-parens'})
		{
			$l =~ s/(\w+)\(\)/<code class=funcname>$1<\/code>/g;
		}
		else
		{
			$l =~ s/(\w+)\(\)/<code class=funcname>$1\(\)<\/code>/g;
		}

		# enclose variable names
		if($opts{'strip-dollars'})
		{
			$l =~ s/(\$)([\w_\.]+)/<code class=varname>$2<\/code>/g;
		}
		else
		{
			$l =~ s/(\$[\w_\.]+)/<code class=varname>$1<\/code>/g;
		}

		# process lists
		if($l =~ /^\s\*\s([\w\s\-]+)\:\s+/)
		{
			if($opts{'dl-as-dl'})
			{
				if($lt ne "dl")
				{
					push(@g,"</$lt>") if $lt;
					push(@g,"<dl>");
				}

				$l =~ s/^\s\*\s([\w\s\-]+)\:\s+/<dt><strong class=strong>$1<\/strong><dd>/;
				$lt='dl';
			}
			else
			{
				if($lt ne "table")
				{
					my ($add);

					push(@g,"</$lt>") if $lt;

					push(@g,"<table $add>");
				}

				$l =~ s/^\s\*\s([\w\s\-]+)\:\s+/<tr><td valign=top><strong class=strong>$1<\/strong class=strong>&nbsp;&nbsp;<\/td><td valign=top>/;
				$lt='table';
			}
		}
		elsif($l =~ /^\s\*\s/ or $l =~ /^\s\-\s/)
		{
			if($lt ne "ul")
			{
				push(@g,"</$lt>") if $lt;
				push(@g,"<ul>");
			}

			$l =~ s/^\s\*\s/<li>/g;
			$l =~ s/^\s\-\s/<li>/g;
			$lt='ul';
		}
		elsif($l =~ /^\s\#\s/ or $l =~ /^\s1\s/)
		{
			if($lt ne "ol")
			{
				push(@g,"</$lt>") if $lt;
				push(@g,"<ol>");
			}

			$l =~ s/^\s\#\s/<li>/g;
			$l =~ s/^\s1\s/<li>/g;
			$lt='ol';
		}
		# table rows
		elsif($tbl and $l =~ /^\s*\|.*\|\s*$/)
		{
			$l =~ s/\|\s*$//;
			$l =~ s/^\s*\|//;

			my @s=split(/\|/,$l);

			for(my $n=0;$n < scalar(@s);$n++)
			{
				$tbl[$n].=' '.$s[$n];
			}

			$l='';
		}
		# table heading / end of row
		elsif($l =~ /^\s*\+[-\+\|]+\+\s*$/)
		{
			if($tbl)
			{
				my ($s,@col_spans);

				if($opts{'class-oddeven'})
				{
					$s=$tblo ? "class=odd" : "class=even";
					$tblo=not $tblo;
				}

				# calculate col spans
				$l =~ s/^\+//;
				$l =~ s/-//g;

				my ($t)=1; @col_spans=();
				for(my $n=0;$n < length($l);$n++)
				{
					if(substr($l,$n,1) eq '+')
					{
						push(@col_spans,$t);
						$t=1;
					}
					else
					{
						# it's a colspan mark:
						# increment
						$t++;
					}
				}

				$l="<tr $s>";
				for(my $n=0;$n < scalar(@tbl);$n++)
				{
					my $i;

					$i=$tbl[$n];
					$i="&nbsp;" if $i =~ /^\s*$/;

					$s.=" colspan=$col_spans[$n]" if $col_spans[$n]>1;

					if($opts{'table-headers'} and $tbl==1)
					{
						$l.="<th $s>$i</th>";
					}
					else
					{
						$l.="<td $s>$i</td>";
					}
				}

				$tbl++;
			}
			else
			{
				my ($add);

				$tbl=1;

				$add="width='100\%'" if $opts{'expand-tables'};
				$add="align=center" if $opts{'center-tables'};

				$l=$opts{'class-oddeven'} ?
					"<table class=oddeven border=1 $add>" :
					"<table border=1 $add>";
			}

			@tbl=();
		}
		elsif($l =~ /^\s/)
		{
			if($lt)
			{
				$g[$#g].=$l;
				$l='';
			}
			else
			{
				push(@g,"<pre>") unless $pre;
				$pre=1;
			}
		}
		else
		{
			push(@g,"</$lt>") if $lt;
			$lt='';

			push(@g,"</pre>") if $pre;
			$pre=0;

			push(@g,"</table>") if $tbl;
			$tbl=0;
		}

		# special headings
		if($l=~/^[-=~]/ and $g[$#g] ne "<p>")
		{
			my ($p,$o);

			$p=pop(@g);

			$o=0;
			$o=1 if($l =~ /^\=+\s*$/);
			$o=2 if($l =~ /^\-+\s*$/);
			$o=3 if($l =~ /^\~+\s*$/);

			if($o)
			{
				$l=sprintf("<h%d class=level$o>$p</h%d>",
					$o+$opts{'header-offset'},
					$o+$opts{'header-offset'});

				# dirty, but works
				$grutatxt_document_name=$p if $o==1;
			}
			else
			{
				push(@g,$p);
			}
		}

		# change ------ into hr
		$l = "<hr noshade size=1>" if $l =~ /^---/;

		push(@g,"$l");
	}

	push(@g,"</pre>") if $pre;
	push(@g,"</$lt>") if $lt;
	push(@g,"</table>") if $tbl;

	return(@g);
}

1;
