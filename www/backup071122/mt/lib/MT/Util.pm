# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Util.pm,v 1.93 2003/05/28 07:48:41 btrott Exp $

package MT::Util;
use strict;

use MT::ConfigMgr;
use MT::Request;
use Exporter;
@MT::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( start_end_day start_end_week start_end_month 
                 html_text_transform encode_html decode_html munge_comment
                 offset_time offset_time_list first_n_words
                 archive_file_for format_ts dirify remove_html
                 days_in wday_from_ts encode_js get_entry spam_protect
                 is_valid_email encode_php encode_url encode_xml
                 decode_xml is_valid_url discover_tb convert_high_ascii );

{
    my @In_Year = (
        [ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365 ],
        [ 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366 ],
    );

    sub wday_from_ts {
        my($y, $m, $d) = @_;
        my $leap = $y % 4 == 0 && ($y % 100 != 0 || $y % 400 == 0) ? 1 : 0;
        $y--;

        ## Copied from Date::Calc.
        my $days = $y * 365;
        $days += $y >>= 2;
        $days -= int($y /= 25);
        $days += $y >> 2;
        $days += $In_Year[$leap][$m-1] + $d;
        $days % 7;
    }

    sub yday_from_ts {
        my($y, $m, $d) = @_;
        my $leap = $y % 4 == 0 && ($y % 100 != 0 || $y % 400 == 0) ? 1 : 0;
        $In_Year[$leap][$m-1] + $d;
    }
}

use vars qw( %Languages );
sub format_ts {
    my($format, $ts, $blog, $lang) = @_;
    my %f;
    unless ($lang) {
        $lang = $blog && $blog->language ? $blog->language : 'en';
    }
    unless (defined $format) {
        $format = $Languages{$lang}[3] || "%B %e, %Y %I:%M %p";
    }
    my $cache = MT::Request->instance->cache('formats');
    unless ($cache) {
        MT::Request->instance->cache('formats', $cache = {});
    }
    if (my $f_ref = $cache->{$ts . $lang}) {
        %f = %$f_ref;
    } else {
        my $L = $Languages{$lang};
        my @ts = @f{qw( Y m d H M S )} = unpack 'A4A2A2A2A2A2', $ts;
        $f{w} = wday_from_ts(@ts[0..2]);
        $f{j} = yday_from_ts(@ts[0..2]);
        $f{'y'} = substr $f{Y}, 2;
        $f{b} = substr $L->[1][$f{'m'}-1] || '', 0, 3;
        $f{B} = $L->[1][$f{'m'}-1];
        $f{a} = substr $L->[0][$f{w}] || '', 0, 3;
        $f{A} = $L->[0][$f{w}];
        ($f{e} = $f{d}) =~ s!^0! !;
        $f{I} = $f{H};
        $f{I} = $f{H};
        if ($f{I} > 12) {
            $f{I} -= 12;
            $f{p} = $L->[2][1];
        } elsif ($f{I} == 0) {
            $f{I} = 12;
            $f{p} = $L->[2][0];
        } elsif ($f{I} == 12) {
            $f{p} = $L->[2][1];
        } else {
            $f{p} = $L->[2][0];
        }
        $f{I} = sprintf "%02d", $f{I};
        ($f{k} = $f{H}) =~ s!^0! !;
        ($f{l} = $f{I}) =~ s!^0! !;
        $f{j} = sprintf "%03d", $f{j};
        $f{Z} = '';
        $cache->{$ts . $lang} = \%f;
    }
    my $date_format = $Languages{$lang}->[4] || "%B %d, %Y";
    my $time_format = $Languages{$lang}->[5] || "%I:%M %p";
    $format =~ s!%x!$date_format!g;
    $format =~ s!%X!$time_format!g;
    ## This is a dreadful hack. I can't think of a good format specifier
    ## for "%B %Y" (which is used for monthly archives, for example) so
    ## I'll just hardcode this, for Japanese dates.
    if ($lang eq 'jp') {
        $format =~ s!%B %Y!$Languages{$lang}->[6]!g;
    }
    $format =~ s!%(\w)!$f{$1}!g if defined $format;
    $format;
}

{
    my @Days_In = ( -1, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
    sub days_in {
        my($m, $y) = @_;
        return $Days_In[$m] unless $m == 2;
        return $y % 4 == 0 && ($y % 100 != 0 || $y % 400 == 0) ?
            29 : 28;
    }
}

sub start_end_day {
    my $day = substr $_[0], 0, 8;
    return $day . '000000' unless wantarray;
    ($day . "000000", $day . "235959");
}

sub start_end_week {
    my($ts) = @_;
    my($y, $mo, $d, $h, $m, $s) = unpack 'A4A2A2A2A2A2', $ts;
    my $wday = wday_from_ts($y, $mo, $d);
    my($sd, $sm, $sy) = ($d - $wday, $mo, $y);
    if ($sd < 1) {
        $sm--;
        $sm = 12, $sy-- if $sm < 1;
        $sd += days_in($sm, $sy);
    }
    my $start = sprintf "%04d%02d%02d%s", $sy, $sm, $sd, "000000";
    return $start unless wantarray;
    my($ed, $em, $ey) = ($d + 6 - $wday, $mo, $y);
    if ($ed > days_in($em, $ey)) {
        $ed -= days_in($em, $ey);
        $em++;
        $em = 1, $ey++ if $em > 12;
    }
    my $end = sprintf "%04d%02d%02d%s", $ey, $em, $ed, "235959";
    ($start, $end);
}

sub start_end_month {
    my($ts) = @_;
    my($y, $mo) = unpack 'A4A2', $ts;
    my $start = sprintf "%04d%02d01000000", $y, $mo;
    return $start unless wantarray;
    my $end = sprintf "%04d%02d%02d235959", $y, $mo, days_in($mo, $y);
    ($start, $end);
}

sub offset_time_list { gmtime offset_time(@_) }

sub offset_time {
    my($ts, $blog, $dir) = @_;
    my $offset;
    if (defined $blog) {
        if (!ref($blog)) {
            require MT::Blog;
            $blog = MT::Blog->load($blog);
        }
        $offset = $blog && $blog->server_offset ? $blog->server_offset : 0;
    } else {
        $offset = MT::ConfigMgr->instance->TimeOffset;
    }
    $offset += 1 if (localtime $ts)[8];
    $offset *= -1 if $dir && $dir eq '-';
    $ts += $offset * 3600;
    $ts;
}

sub html_text_transform {
    my $str = shift;
    $str ||= '';
    my @paras = split /\r?\n\r?\n/, $str;
    for my $p (@paras) {
        if ($p !~ m/^<(?:table|ol|ul|pre|select|form|blockquote|div|q)/) {
            $p =~ s!\r?\n!<br />\n!g;
            $p = "<p>$p</p>";
        }
    }
    join "\n\n", @paras;
}

{
    my %Map = (':' => '&#58;', '@' => '&#64;', '.' => '&#46;');
    sub spam_protect {
        my($str) = @_;
        my $look = join '', keys %Map;
        $str =~ s!([$look])!$Map{$1}!g;
        $str;
    }
}

sub encode_js {
    my($str) = @_;
    return '' unless defined $str;
    $str =~ s!(['"])!\\$1!g;
    $str =~ s!\n!\\n!g;
    $str =~ s!\f!\\f!g;
    $str =~ s!\r!\\r!g;
    $str =~ s!\t!\\t!g;
    $str;
}

sub encode_php {
    my($str, $meth) = @_;
    return '' unless defined $str;
    if ($meth eq 'qq') {
        $str = encode_phphere($str);
        $str =~ s!"!\\"!g;    ## Replace " with \"
    } elsif (substr($meth, 0, 4) eq 'here') {
        $str = encode_phphere($str);
    } else {
        $str =~ s!\\!\\\\!g;  ## Replace \ with \\
        $str =~ s!'!\\'!g;    ## Replace ' with \'
    }
    $str;
}

sub encode_phphere {
    my($str) = @_;
    $str =~ s!\\!\\\\!g;      ## Replace \ with \\
    $str =~ s!\$!\\\$!g;      ## Replace $ with \$
    $str =~ s!\n!\\n!g;       ## Replace character \n with string \n
    $str =~ s!\r!\\r!g;       ## Replace character \r with string \r
    $str =~ s!\t!\\t!g;       ## Replace character \t with string \t
    $str;
}

sub encode_url {
    my($str) = @_;
    $str =~ s!([^a-zA-Z0-9_.-])!uc sprintf "%%%02x", ord($1)!eg;
    $str;
}

{
    my $Have_Entities = eval 'use HTML::Entities; 1' ? 1 : 0;

    sub encode_html {
        my($html, $can_double_encode) = @_;
        return '' unless defined $html;
        $html =~ tr!\cM!!d;
        if ($Have_Entities && !MT::ConfigMgr->instance->NoHTMLEntities) {
            $html = HTML::Entities::encode_entities($html);
        } else {
            if ($can_double_encode) {
                $html =~ s!&!&amp;!g;
            } else {
                ## Encode any & not followed by something that looks like
                ## an entity, numeric or otherwise.
                $html =~ s/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w{1,8});)/&amp;/g;
            }
            $html =~ s!"!&quot;!g;
            $html =~ s!<!&lt;!g;
            $html =~ s!>!&gt;!g;
        }
        $html;
    }

    sub decode_html {
        my($html) = @_;
        return '' unless defined $html;
        $html =~ tr!\cM!!d;
        if ($Have_Entities && !MT::ConfigMgr->instance->NoHTMLEntities) {
            $html = HTML::Entities::decode_entities($html);
        } else {
            $html =~ s!&quot;!"!g;
            $html =~ s!&lt;!<!g;
            $html =~ s!&gt;!>!g;
            $html =~ s!&amp;!&!g;
        }
        $html;
    }
}

{
    my %Map = ('&' => '&amp;', '"' => '&quot;', '<' => '&lt;', '>' => '&gt;',
               '\'' => '&apos;');
    my %Map_Decode = reverse %Map;
    my $RE = join '|', keys %Map;
    my $RE_D = join '|', keys %Map_Decode;

    sub encode_xml {
        my($str) = @_;
        if (!MT::ConfigMgr->instance->NoCDATA && $str =~ m/
            <[^>]+>  ## HTML markup
            |        ## or
            &(?:(?!(\#([0-9]+)|\#x([0-9a-fA-F]+))).*?);
                     ## something that looks like an HTML entity.
        /x) {
            ## If ]]> exists in the string, encode the > to &gt;.
            $str =~ s/]]>/]]&gt;/g;
            $str = '<![CDATA[' . $str . ']]>';
        } else {
            $str =~ s!($RE)!$Map{$1}!g;
        }
        $str;
    }
    sub decode_xml {
        my($str) = @_;
        if ($str =~ s/<!\[CDATA\[(.*?)]]>/$1/g) {
            ## Decode encoded ]]&gt;
            $str =~ s/]]&(gt|#62);/]]>/g;
        } else {
            $str =~ s!($RE_D)!$Map_Decode{$1}!g;
        }
        $str;
    }
}

sub remove_html {
    my($text) = @_;
    $text =~ s!<[^>]+>!!gs;
    $text =~ s!<!&lt;!gs;
    $text;
}

sub dirify {
    my $s = $_[0];
    $s = convert_high_ascii($s);  ## convert high-ASCII chars to 7bit.
    $s = lc $s;                   ## lower-case.
    $s = remove_html($s);         ## remove HTML tags.
    $s =~ s!&[^;\s]+;!!g;         ## remove HTML entities.
    $s =~ s![^\w\s]!!g;           ## remove non-word/space chars.
    $s =~ tr! !_!s;               ## change space chars to underscores.
    $s;    
}

my %HighASCII = (
    "\xc0" => 'A',    # A`
    "\xe0" => 'a',    # a`
    "\xc1" => 'A',    # A'
    "\xe1" => 'a',    # a'
    "\xc2" => 'A',    # A^
    "\xe2" => 'a',    # a^
    "\xc4" => 'Ae',   # A:
    "\xe4" => 'ae',   # a:
    "\xc3" => 'A',    # A~
    "\xe3" => 'a',    # a~
    "\xc8" => 'E',    # E`
    "\xe8" => 'e',    # e`
    "\xc9" => 'E',    # E'
    "\xe9" => 'e',    # e'
    "\xca" => 'E',    # E^
    "\xea" => 'e',    # e^
    "\xcb" => 'Ee',   # E:
    "\xeb" => 'ee',   # e:
    "\xcc" => 'I',    # I`
    "\xec" => 'i',    # i`
    "\xcd" => 'I',    # I'
    "\xed" => 'i',    # i'
    "\xce" => 'I',    # I^
    "\xee" => 'i',    # i^
    "\xcf" => 'Ie',   # I:
    "\xef" => 'ie',   # i:
    "\xd2" => 'O',    # O`
    "\xf2" => 'o',    # o`
    "\xd3" => 'O',    # O'
    "\xf3" => 'o',    # o'
    "\xd4" => 'O',    # O^
    "\xf4" => 'o',    # o^
    "\xd6" => 'Oe',   # O:
    "\xf6" => 'oe',   # o:
    "\xd5" => 'O',    # O~
    "\xf5" => 'o',    # o~
    "\xd8" => 'Oe',   # O/
    "\xf8" => 'oe',   # o/
    "\xd9" => 'U',    # U`
    "\xf9" => 'u',    # u`
    "\xda" => 'U',    # U'
    "\xfa" => 'u',    # u'
    "\xdb" => 'U',    # U^
    "\xfb" => 'u',    # u^
    "\xdc" => 'Ue',   # U:
    "\xfc" => 'ue',   # u:
    "\xc7" => 'C',    # ,C
    "\xe7" => 'c',    # ,c
    "\xd1" => 'N',    # N~
    "\xf1" => 'n',    # n~
    "\xdf" => 'ss',
);
my $HighASCIIRE = join '|', keys %HighASCII;
sub convert_high_ascii {
    my($s) = @_;
    $s =~ s/($HighASCIIRE)/$HighASCII{$1}/g;
    $s;
}

sub first_n_words {
    my($text, $n) = @_;
    $text = remove_html($text);
    my @words = split /\s+/, $text;
    my $max = @words > $n ? $n : @words;
    return join ' ', @words[0..$max-1];
}

sub munge_comment {
    my($text, $blog) = @_;
    unless ($blog->allow_comment_html) {
        $text = remove_html($text);
        if ($blog->autolink_urls) {
            $text =~ s!(http://\S+)!<a href="$1">$1</a>!g;
        }
    }
    $text;
}

my %DynamicURIs = (
    'Individual' => 'entry/<$MTEntryID$>',
    'Weekly'     => 'archives/week/<$MTArchiveDate format="%Y/%m/%d"$>',
    'Monthly'    => 'archives/<$MTArchiveDate format="%Y/%m"$>',
    'Daily'      => 'archives/<$MTArchiveDate format="%Y/%m/%d"$>',
    'Category'   => 'section/<$MTCategoryID$>',
);

sub archive_file_for {
    my($entry, $blog, $at, $cat, $map) = @_;
    return if $at eq 'None';
    my $file;
    if ($blog->is_dynamic) {
        require MT::TemplateMap;
        $map = MT::TemplateMap->new;
        $map->file_template($DynamicURIs{$at});
    }
    unless ($map) {
        my $cache = MT::Request->instance->cache('maps');
        unless ($cache) {
            MT::Request->instance->cache('maps', $cache = {});
        }
        unless ($map = $cache->{$blog->id . $at}) {
            require MT::TemplateMap;
            $map = MT::TemplateMap->load({ blog_id => $blog->id,
                                           archive_type => $at,
                                           is_preferred => 1 });
            $cache->{$blog->id . $at} = $map if $map;
        }
    }
    my $file_tmpl = $map ? $map->file_template : '';
    my($ctx);
    if ($file_tmpl) {
        require MT::Template::Context;
        $ctx = MT::Template::Context->new;
        $ctx->stash('blog', $blog);
    }
    local $ctx->{__stash}{category};
    if ($at eq 'Individual') {
        if ($file_tmpl) {
            $ctx->stash('entry', $entry);
            $ctx->{current_timestamp} = $entry->created_on;
        } else {
            $file = sprintf("%06d", $entry->id);
        }
    } elsif ($at eq 'Daily') {
        if ($file_tmpl) {
            ($ctx->{current_timestamp}, $ctx->{current_timestamp_end}) =
                start_end_day($entry->created_on);
        } else {
            my $start = start_end_day($entry->created_on);
            my($year, $mon, $mday) = unpack 'A4A2A2', $start;
            $file = sprintf("%04d_%02d_%02d", $year, $mon, $mday);
        }
    } elsif ($at eq 'Weekly') {
        if ($file_tmpl) {
            ($ctx->{current_timestamp}, $ctx->{current_timestamp_end}) =
                start_end_week($entry->created_on);
        } else {
            my $start = start_end_week($entry->created_on);
            my($year, $mon, $mday) = unpack 'A4A2A2', $start;
            $file = sprintf("week_%04d_%02d_%02d", $year, $mon, $mday);
        }
    } elsif ($at eq 'Monthly') {
        if ($file_tmpl) {
            ($ctx->{current_timestamp}, $ctx->{current_timestamp_end}) =
                start_end_month($entry->created_on);
        } else {
            my $start = start_end_month($entry->created_on);
            my($year, $mon) = unpack 'A4A2', $start;
            $file = sprintf("%04d_%02d", $year, $mon);
        }
    } elsif ($at eq 'Category') {
        my $this_cat = $cat ? $cat : $entry->category;
        if ($file_tmpl) {
            $ctx->stash('archive_category', $this_cat);
            $ctx->{__stash}{category} = $this_cat;
        } else {
            my $label = '';
            if ($this_cat) {
                $label = dirify($this_cat->label);
            }
            $file = sprintf("cat_%s", $label);
        }
    } else {
        return $entry->error(MT->translate(
            "Invalid Archive Type setting '[_1]'", $at ));
    }
    if ($file_tmpl) {
        require MT::Builder;
        my $build = MT::Builder->new;
        my $tokens = $build->compile($ctx, $file_tmpl) or return;
        defined($file = $build->build($ctx, $tokens)) or return;
    } else {
        my $ext = $blog->file_extension || 'html';
        $file .= '.' . $ext;
    }
    $file;
}

{
    my %Helpers = ( Monthly => \&start_end_month,
                    Weekly => \&start_end_week,
                    Daily => \&start_end_day,
                  );
    sub get_entry {
        my($ts, $blog_id, $at, $order) = @_;
        my($start, $end) = $Helpers{$at}->($ts);
        if ($order eq 'previous') {
            $order = 'descend';
            $ts = $start;
        } else {
            $order = 'ascend';
            $ts = $end;
        }
        my $entry = MT::Entry->load(
            { blog_id => $blog_id,
              status => MT::Entry::RELEASE() },
            { limit => 1,
              'sort' => 'created_on',
              direction => $order,
              start_val => $ts });
        $entry;
    }
}

sub is_valid_email {
    my($addr) = @_;
    if ($addr =~ /[ |\t|\r|\n]*\"?([^\"]+\"?@[^ <>\t]+\.[^ <>\t][^ <>\t]+)[ |\t|\r|\n]*/) {
        return $1;
    } else {
        return 0;
    }
}

sub is_valid_url {
    my($url) = @_;
    if ($url =~ /^(([^:\/?#]+):)?(\/\/([^\/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?/) {
        $url = (($2) && ($2 eq "http")) ? "$1$3$5" : "http://$5";
        $url .= $6 if defined $6;
        $url .= $8 if defined $8;
        return $url;
    } else {
        return 0;
    }
}

sub discover_tb {
    my($url, $find_all, $contents) = @_;
    my $c;
    if ($contents) {
        $c = $$contents;
    } else {
        my $ua = MT->new_ua;
        ## Wrap this in an eval in case some versions don't support it.
        eval { $ua->parse_head(0) };
        my $req = HTTP::Request->new(GET => $url);
        my $res = $ua->request($req);
        return unless $res->is_success;
        $c = $res->content;
    }
    (my $url_no_anchor = $url) =~ s/#.*$//;
    my(@items);
    while ($c =~ m!(<rdf:RDF.*?</rdf:RDF>)!sg) {
        my $rdf = $1;
        my($perm_url) = $rdf =~ m!dc:identifier="([^"]+)"!;
        next unless $find_all ||
            $perm_url eq $url || $perm_url eq $url_no_anchor;
        (my $inner = $rdf) =~ s!^.*?<rdf:Description!!s;
        my $item = { permalink => $perm_url };
        while ($inner =~ /([\w:]+)="([^"]*)"/gs) {
            $item->{$1} = $2;
        }
        ## We look for trackback:ping, but fall back to about
        ## (used in MT 2.2).
        $item->{ping_url} = $item->{'trackback:ping'} || $item->{'rdf:about'} ||
                            $item->{about};
        $item->{title} = $item->{'dc:title'};
        if (!$item->{title} && $rdf =~ m!dc:description="([^"]+)"!) {
            $item->{title} = MT::Util::first_n_words($1, 5) . '...';
        }
        push @items, $item;
        last unless $find_all;
    }
    return unless @items;
    $find_all ? \@items : $items[0];
}

{
    my %Data = (
        'by' => {
              name => 'Attribution',
              requires => [ qw( Attribution Notice ) ],
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
         },
        'by-nd' => {
              name => 'Attribution-NoDerivs',
              requires => [ qw( Attribution Notice ) ],
              permits => [ qw( Reproduction Distribution ) ],
         },
        'by-nd-nc' => {
              name => 'Attribution-NoDerivs-NonCommercial',
              requires => [ qw( Attribution Notice ) ],
              permits => [ qw( Reproduction Distribution ) ],
              prohibits => [ qw( CommercialUse) ],
         },
        'by-nc' => {
              name => 'Attribution-NonCommercial',
              requires => [ qw( Attribution Notice ) ],
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
              prohibits => [ qw( CommercialUse ) ],
         },
        'by-nc-sa' => {
              name => 'Attribution-NonCommercial-ShareAlike',
              requires => [ qw( Attribution Notice ShareAlike ) ],
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
              prohibits => [ qw( CommercialUse ) ],
         },
        'by-sa' => {
              name => 'Attribution-ShareAlike',
              requires => [ qw( Attribution Notice ShareAlike ) ],
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
         },
        'nd' => {
              name => 'NonDerivative',
              requires => [ qw( Notice ) ],
              permits => [ qw( Reproduction Distribution ) ],
         },
        'nd-nc' => {
              name => 'NonDerivative-NonCommercial',
              requires => [ qw( Notice ) ],
              permits => [ qw( Reproduction Distribution ) ],
              prohibits => [ qw( CommercialUse ) ],
         },
        'nc' => {
              name => 'NonCommercial',
              requires => [ qw( Notice ) ],
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
              prohibits => [ qw( CommercialUse ) ],
         },
        'nc-sa' => {
              name => 'NonCommercial-ShareAlike',
              requires => [ qw( Notice ShareAlike ) ],
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
              prohibits => [ qw( CommercialUse ) ],
         },
        'sa' => {
              name => 'ShareAlike',
              requires => [ qw( Notice ShareAlike ) ],
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
         },
        'pd' => {
              name => 'PublicDomain',
              permits => [ qw( Reproduction Distribution DerivativeWorks ) ],
         },
    );
    sub cc_url {
        my($code) = @_;
        $code eq 'pd' ?
            "http://web.resource.org/cc/PublicDomain" :
            "http://creativecommons.org/licenses/$code/1.0/";
    }
    sub cc_rdf {
        my($code) = @_;
        my $url = cc_url($code);
        my $rdf = <<RDF;
<License rdf:about="$url">
RDF
        for my $type (qw( requires permits prohibits )) {
            for my $item (@{ $Data{$code}{$type} }) {
                $rdf .= <<RDF;
<$type rdf:resource="http://web.resource.org/cc/$item" />
RDF
            }
        }
        $rdf . "</License>\n";
    }
    sub cc_name {
        $Data{$_[0]}{name};
    }
}

%Languages = (
    'en' => [
            [ qw( Sunday Monday Tuesday Wednesday Thursday Friday Saturday ) ],
            [ qw( January February March April May June
                  July August September October November December ) ],
            [ qw( AM PM ) ],
          ],

    'fr' => [
            [ qw( dimanche lundi mardi mercredi jeudi vendredi samedi ) ],
            [ ('janvier', "f\xe9vrier", 'mars', 'avril', 'mai', 'juin',
               'juillet', "ao\xfbt", 'septembre', 'octobre', 'novembre',
               "d\xe9cembre") ],
            [ qw( AM PM ) ],
          ],

    'es' => [
            [ ('Domingo', 'Lunes', 'Martes', "Mi\xe9rcoles", 'Jueves',
               'Viernes', "S\xe1bado") ],
            [ qw( Enero Febrero Marzo Abril Mayo Junio Julio Agosto
                  Septiembre Octubre Noviembre Diciembre ) ],
            [ qw( AM PM ) ],
          ],

    'pt' => [
            [ ('domingo', 'segunda-feira', "ter\xe7a-feira", 'quarta-feira',
               'quinta-feira', 'sexta-feira', "s\xe1bado") ],
            [ ('janeiro', 'fevereiro', "mar\xe7o", 'abril', 'maio', 'junho',
               'julho', 'agosto', 'setembro', 'outubro', 'novembro',
               'dezembro' ) ],
            [ qw( AM PM ) ],
          ],

    'nl' => [
            [ qw( zondag maandag dinsdag woensdag donderdag vrijdag
                  zaterdag ) ],
            [ qw( januari februari maart april mei juni juli augustus
                  september oktober november december ) ],
            [ qw( am pm ) ],
          ],

    'dk' => [
            [ ("s\xf8ndag", 'mandag', 'tirsdag', 'onsdag', 'torsdag',
               'fredag', "l\xf8rdag") ],
            [ qw( januar februar marts april maj juni juli august
                  september oktober november december ) ],
            [ qw( am pm ) ],
            "%d.%m.%Y %H:%M",
            "%d.%m.%Y",
            "%H:%M",
          ],

    'se' => [
            [ ("s\xf6ndag", "m\xe5ndag", 'tisdag', 'onsdag', 'torsdag',
               'fredag', "l\xf6rdag") ],
            [ qw( januari februari mars april maj juni juli augusti
                  september oktober november december ) ],
            [ qw( FM EM ) ],
          ],

    'no' => [
            [ ("S\xf8ndag", "Mandag", 'Tirsdag', 'Onsdag', 'Torsdag',
               'Fredag', "L\xf8rdag") ],
            [ qw( Januar Februar Mars April Mai Juni Juli August
                  September Oktober November Desember ) ],
            [ qw( FM EM ) ],
          ],

    'de' => [
            [ qw( Sonntag Montag Dienstag Mittwoch Donnerstag Freitag
                  Samstag ) ],
            [ ('Januar', 'Februar', "M\xe4rz", 'April', 'Mai', 'Juni',
               'Juli', 'August', 'September', 'Oktober', 'November',
               'Dezember') ],
            [ qw( FM EM ) ],
            "%d.%m.%y %H:%M",
            "%d.%m.%y",
            "%H:%M",
          ],

    'it' => [
            [ ('Domenica', "Luned\xec", "Marted\xec", "Mercoled\xec",
               "Gioved\xec", "Venerd\xec", 'Sabato') ],
            [ qw( Gennaio Febbraio Marzo Aprile Maggio Giugno Luglio
                  Agosto Settembre Ottobre Novembre Dicembre ) ],
            [ qw( AM PM ) ],
            "%d.%m.%y %H:%M",
            "%d.%m.%y",
            "%H:%M",
          ],

    'pl' => [
            [ ('niedziela', "poniedzia&#322;ek", 'wtorek', "&#347;roda",
               'czwartek', "pi&#261;tek", 'sobota') ],
            [ ('stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
               'lipca', 'sierpnia', "wrze&#347;nia", "pa&#378;dziernika",
               'listopada', 'grudnia') ],
            [ qw( AM PM ) ],
            "%e %B %Y %k:%M",
            "%e %B %Y",
            "%k:%M",
          ],

    'fi' => [
            [ qw( sunnuntai maanantai tiistai keskiviikko torstai perjantai
                  lauantai ) ],
            [ ('tammikuu', 'helmikuu', 'maaliskuu', 'huhtikuu', 'toukokuu',
               "kes\xe4kuu", "hein\xe4kuu", 'elokuu', 'syyskuu', 'lokakuu',
               'marraskuu', 'joulukuu') ],
            [ qw( AM PM ) ],
            "%d.%m.%y %H:%M",
          ],

    'is' => [
            [ ('Sunnudagur', "M\xe1nudagur", "\xderi\xf0judagur",
               "Mi\xf0vikudagur", 'Fimmtudagur', "F\xf6studagur",
               'Laugardagur') ],
            [ ("jan\xfaar", "febr\xfaar", 'mars', "apr\xedl", "ma\xed",
               "j\xfan\xed", "j\xfal\xed", "\xe1g\xfast", 'september',
               "okt\xf3ber", "n\xf3vember", 'desember') ],
            [ qw( FH EH ) ],
            "%d.%m.%y %H:%M",
          ],

    'si' => [
            [ ('nedelja', 'ponedeljek', 'torek', 'sreda', "\xe3etrtek",
               'petek', 'sobota',) ],
            [ qw( januar februar marec april maj junij julij avgust
                  september oktober november december ) ],
            [ qw( AM PM ) ],
            "%d.%m.%y %H:%M",
          ],

    'cz' => [
            [ ('Ned&#283;le', 'Pond&#283;l&#237;', '&#218;ter&#253;',
               'St&#345;eda', '&#268;tvrtek', 'P&#225;tek', 'Sobota') ],
            [ ('Leden', '&#218;nor', 'B&#345;ezen', 'Duben', 'Kv&#283;ten',
               '&#268;erven', '&#268;ervenec', 'Srpen', 'Z&#225;&#345;&#237;',
               '&#216;&#237;jen', 'Listopad', 'Prosinec') ],
            [ qw( AM PM ) ],
            "%e. %B %Y %k:%M",
            "%e. %B %Y",
            "%k:%M",
          ],

    'sk' => [
            [ ('nede&#318;a', 'pondelok', 'utorok', 'streda',
               '&#353;tvrtok', 'piatok', 'sobota') ],
            [ ('janu&#225;r', 'febru&#225;r', 'marec', 'apr&#237;l',
               'm&#225;j', 'j&#250;n', 'j&#250;l', 'august', 'september',
               'okt&#243;ber', 'november', 'december') ],
            [ qw( AM PM ) ],
            "%e. %B %Y %k:%M",
            "%e. %B %Y",
            "%k:%M",
          ],

    'jp' => [
            [ '&#26085;&#26332;&#26085;', '&#26376;&#26332;&#26085;',
              '&#28779;&#26332;&#26085;', '&#26408;&#26332;&#26085;',
              '&#27700;&#26332;&#26085;', '&#37329;&#26332;&#26085;',
              '&#22303;&#26332;&#26085;'],
            [ qw( 1 2 3 4 5 6 7 8 9 10 11 12 ) ],
            [ qw( AM PM ) ],
            "%Y&#24180;%m&#26376;%d&#26085; %H:%M",
            "%Y&#24180;%m&#26376;%d&#26085;",
            "%H:%M",
            "%Y&#24180;%m&#26376;",
          ],

    'et' => [
            [ qw( p&uuml;hap&auml;ev esmasp&auml;ev teisip&auml;ev
                  kolmap&auml;ev neljap&auml;ev reede laup&auml;ev ) ],
            [ ('jaanuar', 'veebruar', 'm&auml;rts', 'aprill', 'mai',
               'juuni', 'juuli', 'august', 'september', 'oktoober',
              'november', 'detsember') ],
            [ qw( AM PM ) ],
            "%m.%d.%y %H:%M",
            "%e. %B %Y",
            "%H:%M",
          ],
);

1;
__END__

=head1 NAME

MT::Util - Movable Type utility functions

=head1 SYNOPSIS

    use MT::Util qw( functions );

=head1 DESCRIPTION

I<MT::Util> provides a variety of utility functions used by the Movable Type
libraries.

=head1 USAGE

=head2 start_end_day($ts)

Given I<$ts>, a timestamp in form C<YYYYMMDDHHMMSS>, calculates the timestamp
corresponding to the start of the same day, and, if called in list context,
the end of the day. If called in scalar context, returns one timestamp
corresponding to the start of the day; if called in list context, returns two
timestamps, for the start and end of the day.

For example, given C<20020410160406>, returns C<20020410000000> in scalar
context, and C<20020410000000> and C<20020410235959> in list context.

=head2 start_end_week($ts)

Given I<$ts>, a timestamp in form C<YYYYMMDDHHMMSS>, calculates the timestamp
corresponding to the start of the week, and, if called in list context, the
end of the week. If called in scalar context, returns one timestamp
corresponding to the start of the week; if called in list context, returns two
timestamps, for the start and end of the week.

A week is defined as starting on Sunday.

For example, given C<20020410160406>, returns C<20020407000000> in scalar
context, and C<20020407000000> and C<20020413235959> in list context.

=head2 start_end_month($ts)

Given I<$ts>, a timestamp in form C<YYYYMMDDHHMMSS>, calculates the timestamp
corresponding to the start of the month, and, if called in list context,
the end of the month. If called in scalar context, returns one timestamp
corresponding to the start of the month; if called in list context, returns two
timestamps, for the start and end of the month.

For example, given C<20020410160406>, returns C<20020401000000> in scalar
context, and C<20020401000000> and C<20020430235959> in list context.

=head2 offset_time_list($unix_ts, $blog [, $direction ])

Given I<$unix_ts>, a timestamp in Unix epoch format (seconds since 1970),
applies the timezone offset specified in the blog I<$blog> (either an
I<MT::Blog> object or a numeric blog ID). If daylight saving time is in
effect in the local time zone (determined using the return value from
I<localtime()>), the offset is automatically adjusted.

Returns the return value of I<gmtime()> given the adjusted Unix timestamp.

=head2 format_ts($format, $ts, $blog)

Given a timestamp I<$ts> in form C<YYYYMMDDHHMMSS>, applies the format
specified in I<$format> and returns the formatted string.

If specified, I<$blog> should be an I<MT::Blog> object, from which the
date/time formatting language preference is taken (e.g. English, French, etc.).
If unspecified, English formatting is used.

If I<$format> is C<undef>, and I<$blog> is specified, I<format_ts> will
use a language-specific default format; if a language-specific format is not
defined, or if I<$blog> is unspecified, the default format used is
C<%B %e, %Y %I:%M %p>.

=head2 days_in($month, $year)

Returns the number of days in the month I<$month> in the year I<$year>.
I<$month> should be numeric, starting at C<1> for C<January>. I<$year> should
be a 4-digit year. The number of days is automatically adjusted in a leap
year.

=head2 wday_from_ts($year, $month, $day)

Returns the numeric day of the week, in the range C<0>-C<6>, where C<0> is
C<Sunday>, for the date specified in I<$year>, I<$month>, and I<$day>.
I<$year> should be a 4-digit year; I<$month> a numeric value in the range
C<1>-C<12>; and I<$day> the numeric day of the month.

=head2 first_n_words($str, $n)

Given a string I<$str>, returns the first I<$n> words in the string, after
removing any HTML tags.

=head2 dirify($str)

Munges a string I<$str> so that it is suitable for use as a file/directory
name. HTML is removed; HTML-entities are removed; non-word/space characters
are removed; spaces are changed to underscores; the entire string is
converted to lower-case.

For example, the string C<Foo E<lt>bE<gt>BarE<lt>/bE<gt> E<amp>quot;BazE<amp>quot;> would be transformed into C<foo_bar_baz>.

=head2 encode_html($str)

Encodes any special characters in I<$str> into HTML entities and returns the
transformed string.

If I<HTML::Entities> is available, and if the configuration setting
I<NoHTMLEntities> is not set, uses I<HTML::Entities> for entity-encoding.
Otherwise, very simple encoding is done to catch the most common characters
that need encoding.

=head2 decode_html($str)

Decodes any HTML entities in I<$str> into the corresponding characters and
returns the transformed string.

If I<HTML::Entities> is available, and if the configuration setting
I<NoHTMLEntities> is not set, uses I<HTML::Entities> for entity-decoding.
Otherwise, very simple decoding is done to catch the most common entities
that need decoding.

=head2 remove_html($str)

Removes any HTML tags from I<$str> and returns the result.

=head2 encode_js($str)

Escapes/encodes any special characters in I<$str> so that the string can be
used safely as the value in Javascript; returns the transformed string.

=head2 encode_php($str [, $type ])

Escapes/encodes any special characters in I<$str> so that the string can be
used safely as the value in PHP code; returns the transformed string.

I<$type> can be either C<qq> (double-quote interpolation), C<here> (heredoc
interpolation), or C<q> (single-quote interpolation). C<q> is the default.

=head2 spam_protect($email_address)

Given an email address I<$email_address>, encodes any characters that will
identify it as an email address (C<:>, C<@>, and C<.>) into HTML entities,
so that spam harvesters will not see the email address as easily. Returns
the transformed address.

=head2 is_valid_email($email_address)

Checks the email address I<$email_address> for syntax validity; if the
address--or part of it--is valid, I<is_valid_email> returns the valid (part
of) the email address. Otherwise, it returns C<0>.

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
