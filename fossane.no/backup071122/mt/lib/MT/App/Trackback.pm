# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Trackback.pm,v 1.27 2003/02/24 01:45:55 btrott Exp $

package MT::App::Trackback;
use strict;

use File::Spec;
use MT::TBPing;
use MT::Trackback;
use MT::Util qw( first_n_words encode_xml is_valid_url );
use MT::App;
@MT::App::Trackback::ISA = qw( MT::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        ping => \&ping,
        view => \&view,
        rss => \&rss,
    );
    $app->{default_mode} = 'ping';
    $app->{charset} = $app->{cfg}->PublishCharset;
    $app;
}

sub view {
    my $app = shift;
    my $q = $app->{query};
    require MT::Template;
    require MT::Template::Context;
    require MT::Entry;
    my $entry_id = $q->param('entry_id');
    my $entry = MT::Entry->load($entry_id)
        or return $app->error($app->translate(
            "Invalid entry ID '[_1]'", $entry_id));
    my $ctx = MT::Template::Context->new;
    $ctx->stash('entry', $entry);
    $ctx->{current_timestamp} = $entry->created_on;
    my $tmpl = MT::Template->load({ type => 'pings',
                                    blog_id => $entry->blog_id })
        or return $app->error($app->translate(
            "You must define a Ping template in order to display pings."));
    defined(my $html = $tmpl->build($ctx))
        or return $app->error($tmpl->errstr);
    $html;
}

## The following subroutine strips the UTF8 flag from a string, thus
## forcing it into a series of bytes. "pack 'C0'" is a magic way of
## forcing the following string to be packed as bytes, not as UTF8.
sub no_utf8 {
    for (@_) {
        next if !defined $_;
        $_ = pack 'C0A*', $_;
    }
}

my %map = ('&' => '&amp;', '"' => '&quot;', '<' => '&lt;', '>' => '&gt;');
sub _response {
    my $app = shift;
    my %param = @_;
    $app->send_http_header('text/xml');
    $app->{no_print_body} = 1;

    if (my $err = $param{Error}) {
        my $re = join '|', keys %map;
        $err =~ s!($re)!$map{$1}!g;
        print <<XML;
<?xml version="1.0" encoding="iso-8859-1"?>
<response>
<error>1</error>
<message>$err</message>
</response>
XML
    } else {
        print <<XML;
<?xml version="1.0" encoding="iso-8859-1"?>
<response>
<error>0</error>
XML
        if (my $rss = $param{RSS}) {
            print $rss;
        }
        print <<XML;
</response>
XML
    }

    1;
}

sub _get_params {
    my $app = shift;
    my($tb_id, $pass);
    if ($tb_id = $app->{query}->param('tb_id')) {
        $pass = $app->{query}->param('pass');
    } else {
        if (my $pi = $app->path_info) {
            $pi =~ s!^/!!;
            $pi =~ s!^\D*!!;
            ($tb_id, $pass) = split /\//, $pi;
        }
    }
    ($tb_id, $pass);
}

sub ping {
    my $app = shift;
    my $q = $app->{query};
    my($tb_id, $pass) = $app->_get_params;
    return $app->_response(Error =>
           $app->translate("Need a TrackBack ID (tb_id)."))
        unless $tb_id;

    my($title, $excerpt, $url, $blog_name) = map scalar $q->param($_),
                                             qw( title excerpt url blog_name);

    no_utf8($tb_id, $title, $excerpt, $url, $blog_name);

    return $app->_response(Error => $app->translate("Need a Source URL (url)."))
        unless $url;

    if (my $fixed = MT::Util::is_valid_url($url)) {
        $url = $fixed; 
    } else {
        return $app->_response(Error =>
            $app->translate("Invalid URL '[_1]'", $url));
    }

    require MT::TBPing;
    require MT::Trackback;

    my $tb = MT::Trackback->load($tb_id)
        or return $app->_response(Error =>
            $app->translate("Invalid TrackBack ID '[_1]'", $tb_id));

    return $app->_response(Error =>
        $app->translate("This TrackBack item is disabled."))
        if $tb->is_disabled;

    if ($tb->passphrase && (!$pass || $pass ne $tb->passphrase)) {
        return $app->_response(Error =>
          $app->translate("This TrackBack item is protected by a passphrase."));
    }

    ## Check if this user has been banned from sending TrackBack pings.
    require MT::IPBanList;
    my $iter = MT::IPBanList->load_iter({ blog_id => $tb->blog_id });
    my $user_ip = $app->remote_ip;
    while (my $ban = $iter->()) {
        my $banned_ip = $ban->ip;
        if ($user_ip =~ /$banned_ip/) {
            return $app->_response(Error =>
              $app->translate("You are not allowed to send TrackBack pings."));
        }
    }

    ## Check if user has pinged recently
    #my @past = MT::TBPing->load({ tb_id => $tb_id, ip => $host_ip });
    #if (@past) {
    #    @past = sort { $b->created_on cmp $a->created_on } @past;
    #}

    my $ping = MT::TBPing->new;
    $ping->blog_id($tb->blog_id);
    $ping->tb_id($tb_id);
    $ping->source_url($url);
    $ping->ip($app->remote_ip || '');
    if ($excerpt) {
        if (length($excerpt) > 255) {
            $excerpt = substr($excerpt, 0, 252) . '...';
        }
        $title = first_n_words($excerpt, 5)
            unless defined $title;
        $ping->excerpt($excerpt);
    }
    $ping->title(defined $title && $title ne '' ? $title : $url);
    $ping->blog_name($blog_name);
    $ping->save;

    ## If this is a trackback item for a particular entry, we need to
    ## rebuild the indexes in case the <$MTEntryTrackbackCount$> tag
    ## is being used. We also want to place the RSS files inside of the
    ## Local Site Path.
    my($blog_id, $entry, $cat);
    if ($tb->entry_id) {
        require MT::Entry;
        $entry = MT::Entry->load($tb->entry_id);
        $blog_id = $entry->blog_id;
    } elsif ($tb->category_id) {
        require MT::Category;
        $cat = MT::Category->load($tb->category_id);
        $blog_id = $cat->blog_id;
    }
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    $app->rebuild_indexes( Blog => $blog )
        or return $app->_response(Error =>
            $app->translate("Rebuild failed: [_1]", $app->errstr));

    if ($app->{cfg}->GenerateTrackBackRSS) {
        ## Now generate RSS feed for this trackback item.
        my $rss = _generate_rss($tb, 10);
        my $base = $blog->archive_path;
        my $feed = File::Spec->catfile($base, $tb->rss_file || $tb->id . '.xml');
        my $fmgr = $blog->file_mgr;
        $fmgr->put_data($rss, $feed)
            or return $app->_response(Error =>
                $app->translate("Can't create RSS feed '[_1]': ", $feed,
                $fmgr->errstr));
    }

    if ($blog->email_new_pings) {
        require MT::Mail;
        my($author, $subj, $body);
        if ($entry) {
            $author = $entry->author;
            $app->set_language($author->preferred_language)
                if $author && $author->preferred_language;
            $subj = $app->translate('New TrackBack Ping to Entry [_1] ([_2])',
                $entry->id, $entry->title);
            $body = $app->translate('A new TrackBack ping has been sent to your weblog, on the entry [_1] ([_2]).', $entry->id, $entry->title);
        } elsif ($cat) {
            require MT::Author;
            $author = MT::Author->load($cat->created_by);
            $app->set_language($author->preferred_language)
                if $author && $author->preferred_language;
            $subj = $app->translate('New TrackBack Ping to Category [_1] ([_2])',
                $cat->id, $cat->label);
            $body = $app->translate('A new TrackBack ping has been sent to your weblog, on the category [_1] ([_2]).', $cat->id, $cat->label);
        }
        if ($author && $author->email) {
            my %head = ( To => $author->email,
                         From => $author->email,
                         Subject => '[' . $blog->name . '] ' . $subj );
            my $charset = $app->{cfg}->PublishCharset || 'iso-8859-1';
            $head{'Content-Type'} = qq(text/plain; charset="$charset");
            require Text::Wrap;
            $Text::Wrap::cols = 72;
            $body = Text::Wrap::wrap('', '', $body) . "\n\n" .
                 $app->translate('IP Address:') . ' ' . $ping->ip . "\n" .
                 $app->translate('URL:') . ' ' . $ping->source_url . "\n" .
                 $app->translate('Title:') . ' ' . $ping->title . "\n" .
                 $app->translate('Weblog:') . ' ' . $ping->blog_name . "\n\n" .
                 $app->translate('Excerpt:') . "\n" . $ping->excerpt . "\n";
            MT::Mail->send(\%head, $body);
        }
    }

    return $app->_response;
}

sub rss {
    my $app = shift;
    my($tb_id, $pass) = $app->_get_params;
    my $tb = MT::Trackback->load($tb_id)
        or return $app->_response(Error =>
            $app->translate("Invalid TrackBack ID '[_1]'", $tb_id));
    my $rss = _generate_rss($tb);
    $app->_response(RSS => $rss);
}

sub _generate_rss {
    my($tb, $lastn) = @_;
    my $rss = <<RSS;
<rss version="0.91"><channel>
<title>@{[ $tb->title ]}</title>
<link>@{[ $tb->url || '' ]}</link>
<description>@{[ $tb->description || '' ]}</description>
<language>en-us</language>
RSS
    my %arg;
    if ($lastn) {
        %arg = ('sort' => 'created_on', direction => 'descend',
                limit => $lastn);
    }
    my $iter = MT::TBPing->load_iter({ tb_id => $tb->id }, \%arg);
    while (my $ping = $iter->()) {
        $rss .= sprintf qq(<item>\n<title>%s</title>\n<link>%s</link>\n),
            encode_xml($ping->title), encode_xml($ping->source_url);
        if ($ping->excerpt) {
            $rss .= sprintf qq(<description>%s</description>\n),
                encode_xml($ping->excerpt);
        }
        $rss .= qq(</item>\n);
    }
    $rss .= qq(</channel>\n</rss>);
    $rss;
}

1;
