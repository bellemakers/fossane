# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: MT.pm,v 1.136 2003/05/28 09:02:32 btrott Exp $

package MT;
use strict;

use vars qw( $VERSION );
$VERSION = '2.64';

use MT::ConfigMgr;
use MT::Object;
use MT::Blog;
use MT::Util qw( start_end_day start_end_week start_end_month
                 archive_file_for get_entry );
use File::Spec;
use File::Basename;
use Fcntl qw( LOCK_EX );

use MT::ErrorHandler;
@MT::ISA = qw( MT::ErrorHandler );

use vars qw( %Text_filters );

sub version_number {
    (my $ver = $VERSION) =~ s/[^\d\.].*$//;
    $ver;
}

sub version_slug {
    return <<SLUG;
Powered by Movable Type
Version $VERSION
http://www.movabletype.org/
SLUG
}

sub new {
    my $class = shift;
    my $mt = bless { }, $class;
    $mt->init(@_) or
        return $class->error($mt->errstr);
    $mt;
}

sub init {
    my $mt = shift;
    my %param = @_;

    MT->add_text_filter(__default__ => {
        label => 'Convert Line Breaks',
        on_format => sub { MT::Util::html_text_transform($_[0]) },
    });

    ## Initialize the language to English in case any errors occur in
    ## the rest of the initialization process.
    $mt->set_language('en_us');
    my $cfg = $mt->{cfg} = MT::ConfigMgr->instance;
    my($cfg_file);
    unless ($cfg_file = $param{Config}) {
        for my $f (qw( mt.cfg )) {
            $cfg_file = $f, last if -r $f;
        }
    }
    if ($cfg_file) {
        $cfg->read_config($cfg_file) or
            return $mt->error($cfg->errstr);
    }
    if (my $dir = $param{Directory}) {
        $mt->{mt_dir} = $dir;
    } elsif ($cfg_file) {
        $mt->{mt_dir} = dirname($cfg_file) || './';
    }
    my %default_dirs = (
        TemplatePath => 'tmpl',
        ImportPath => 'import',
        PluginPath => 'plugins',
        SearchTemplatePath => 'search_templates',
    );
    for my $meth (keys %default_dirs) {
        $cfg->$meth(File::Spec->catfile($mt->{mt_dir}, $default_dirs{$meth}))
            unless defined $cfg->$meth();
    }
    if ($cfg->ObjectDriver =~ /DBI::(?:mysql|postgres)/) {
        my $pass_file = File::Spec->catfile($mt->{mt_dir}, 'mt-db-pass.cgi');
        local *FH;
        if (open FH, $pass_file) {
            my $pass = <FH>;
            close FH;
            if ($pass) {
                chomp($pass);
                $pass =~ s!^\s*!!;
                $pass =~ s!\s*$!!;
            }
            $cfg->DBPassword($pass);
        }
    }
    MT::Object->set_driver($cfg->ObjectDriver)
        or return $mt->error(MT::ObjectDriver->errstr);
    $mt->set_language($cfg->DefaultLanguage);
    $mt->{__rebuilt} = {};
    $mt->{__cached_maps} = {};
    $mt->{__cached_templates} = {};
    my $plugin_dir = $cfg->PluginPath;
    local *DH;
    if (opendir DH, $plugin_dir) {
        my @p = readdir DH;
        for my $plugin (@p) {
            next if $plugin !~ /\.pl$/;
            $plugin = File::Spec->catfile($plugin_dir, $plugin);
            if ($plugin =~ /^([-\\\/\@\:\w\.\s]+)$/) {
                $plugin = $1;
            } else {
                die "Bad plugin filename '$plugin'";
            }
            eval { require $plugin };
            warn($@), next if $@;
        }
        closedir DH;
    }
    $mt;
}

sub rebuild {
    my $mt = shift;
    my %param = @_;
    my $blog;
    unless ($blog = $param{Blog}) {
        my $blog_id = $param{BlogID};
        $blog = MT::Blog->load($blog_id) or
            return $mt->error(
                $mt->translate("Load of blog '[_1]' failed: [_2]",
                    $blog_id, MT::Blog->errstr));
    }
    return 1 if $blog->is_dynamic;
    my $at = $blog->archive_type || '';
    my @at = split /,/, $at;
    if (my $set_at = $param{ArchiveType}) {
        my %at = map { $_ => 1 } @at;
        return $mt->error(
            $mt->translate("Archive type '[_1]' is not a chosen archive type",
                $set_at)) unless $at{$set_at};
        @at = ($set_at);
    }
    if (@at) {
        require MT::Entry;
        my %arg = ('sort' => 'created_on', direction => 'descend');
        if ($param{Limit}) {
            $arg{offset} = $param{Offset};
            $arg{limit} = $param{Limit};
        }
        my $iter = MT::Entry->load_iter({ blog_id => $blog->id,
                                          status => MT::Entry::RELEASE() },
            \%arg);
        my $cb = $param{EntryCallback};
        while (my $entry = $iter->()) {
            $cb->($entry) if $cb;
            for my $at (@at) {
                if ($at eq 'Category') {
                    my $cats = $entry->categories;
                    for my $cat (@$cats) {
                        $mt->_rebuild_entry_archive_type(
                            Entry => $entry, Blog => $blog,
                            Category => $cat, ArchiveType => 'Category'
                        ) or return;
                    }
                } else {
                    $mt->_rebuild_entry_archive_type( Entry => $entry,
                                                      Blog => $blog,
                                                      ArchiveType => $at )
                        or return;
                }
            }
        }
    }
    unless ($param{NoIndexes}) {
        $mt->rebuild_indexes( Blog => $blog ) or return;
    }
    1;
}

sub rebuild_entry {
    my $mt = shift;
    my %param = @_;
    my $entry = $param{Entry} or
        return $mt->error($mt->translate("Parameter '[_1]' is required",
            'Entry'));
    my $blog;
    unless ($blog = $param{Blog}) {
        my $blog_id = $entry->blog_id;
        $blog = MT::Blog->load($blog_id) or
            return $mt->error($mt->translate("Load of blog '[_1]' failed: [_2]",
                $blog_id, MT::Blog->errstr));
    }
    return 1 if $blog->is_dynamic;
    my $at = $blog->archive_type;
    if ($at && $at ne 'None') {
        my @at = split /,/, $at;
        for my $at (@at) {
            if ($at eq 'Category') {
                my $cats = $entry->categories;
                for my $cat (@$cats) {
                    $mt->_rebuild_entry_archive_type(
                        Entry => $entry, Blog => $blog,
                        ArchiveType => $at, Category => $cat,
                    ) or return;
                }
            } else {
                $mt->_rebuild_entry_archive_type( Entry => $entry,
                                                  Blog => $blog,
                                                  ArchiveType => $at
                ) or return;
            }
        }
    }

    ## The above will just rebuild the archive pages for this particular
    ## entry. If we want to rebuild all of the entries/archives/indexes
    ## on which this entry could be featured etc., however, we need to
    ## rebuild all of the entry's dependencies. Note that all of these
    ## are not *necessarily* dependencies, depending on the usage of tags,
    ## etc. There is not a good way to determine exact dependencies; it is
    ## easier to just rebuild, rebuild, rebuild.

    return 1 unless $param{BuildDependencies};

    ## Rebuild previous and next entry archive pages.
    if (my $prev = $entry->previous(1)) {
        $mt->rebuild_entry( Entry => $prev ) or return;
    }
    if (my $next = $entry->next(1)) {
        $mt->rebuild_entry( Entry => $next ) or return;
    }

    ## Rebuild all indexes, in case this entry is on an index.
    $mt->rebuild_indexes( Blog => $blog ) or return;

    ## Rebuild previous and next daily, weekly, and monthly archives;
    ## adding a new entry could cause changes to the intra-archive
    ## navigation.
    my %at = map { $_ => 1 } split /,/, $blog->archive_type;
    for my $at (qw( Daily Weekly Monthly )) {
        if ($at{$at}) {
            my @arg = ($entry->created_on, $entry->blog_id, $at);
            if (my $prev_arch = get_entry(@arg, 'previous')) {
                $mt->_rebuild_entry_archive_type(
                          Entry => $prev_arch,
                          Blog => $blog,
                          ArchiveType => $at) or return;
            }
            if (my $next_arch = get_entry(@arg, 'next')) {
                $mt->_rebuild_entry_archive_type(
                          Entry => $next_arch,
                          Blog => $blog,
                          ArchiveType => $at) or return;
            }
        }
    }

    1;
}

sub _rebuild_entry_archive_type {
    my $mt = shift;
    my %param = @_;
    my $at = $param{ArchiveType} or
        return $mt->error($mt->translate("Parameter '[_1]' is required",
            'ArchiveType'));
    return 1 if $at eq 'None';
    my $entry = $param{Entry} or
        return $mt->error($mt->translate("Parameter '[_1]' is required",
            'Entry'));
    my $blog;
    unless ($blog = $param{Blog}) {
        my $blog_id = $entry->blog_id;
        $blog = MT::Blog->load($blog_id) or
            return $mt->error($mt->translate("Load of blog '[_1]' failed: [_2]",
                $blog_id, MT::Blog->errstr));
    }
    return 1 if $blog->is_dynamic;

    ## Load the template-archive-type map entries for this blog and
    ## archive type. We do this before we load the list of entries, because
    ## we will run through the files and check if we even need to rebuild
    ## anything. If there is nothing to rebuild at all for this entry,
    ## we save some time by not loading the list of entries.
    require MT::TemplateMap;
    my @map;
    if (my $maps = $mt->{__cached_maps}{$at . $blog->id}) {
        @map = @$maps;
    } else {
        @map = MT::TemplateMap->load({ archive_type => $at,
                                       blog_id => $blog->id });
        $mt->{__cached_maps}{$at . $blog->id} = \@map;
    }
    return $mt->error($mt->translate(
        "You selected the archive type '[_1]', but you did not " .
        "define a template for this archive type.", $at)) unless @map;
    my @map_build;
    ## We keep a running total of the pages we have rebuilt
    ## in this session in $mt->{__rebuilt}.
    my $done = $mt->{__rebuilt};
    for my $map (@map) {
        my $file = archive_file_for($entry, $blog, $at, $param{Category}, $map);
        push @map_build, $map unless $done->{$file};
        $map->{__saved_output_file} = $file;
    }
    return 1 unless @map_build;
    @map = @map_build;

    my(%cond);
    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    $ctx->{current_archive_type} = $at;

    if ($at eq 'Individual') {
        $ctx->stash('entry', $entry);
        $ctx->{current_timestamp} = $entry->created_on;
        $cond{EntryIfAllowComments} = $entry->allow_comments;
        $cond{EntryIfCommentsOpen} = $entry->allow_comments eq '1';
        $cond{EntryIfAllowPings} = $entry->allow_pings;
        $cond{EntryIfExtended} = $entry->text_more ? 1 : 0;
    } elsif ($at eq 'Daily') {
        my($start, $end) = start_end_day($entry->created_on, $blog);
        $ctx->{current_timestamp} = $start;
        $ctx->{current_timestamp_end} = $end;
        my @entries = MT::Entry->load({ created_on => [ $start, $end ],
                                        blog_id => $blog->id,
                                        status => MT::Entry::RELEASE() },
                                      { range => { created_on => 1 } });
        $ctx->stash('entries', \@entries);
    } elsif ($at eq 'Weekly') {
        my($start, $end) = start_end_week($entry->created_on, $blog);
        $ctx->{current_timestamp} = $start;
        $ctx->{current_timestamp_end} = $end;
        my @entries = MT::Entry->load({ created_on => [ $start, $end ],
                                        blog_id => $blog->id,
                                        status => MT::Entry::RELEASE() },
                                      { range => { created_on => 1 } });
        $ctx->stash('entries', \@entries);
    } elsif ($at eq 'Monthly') {
        my($start, $end) = start_end_month($entry->created_on, $blog);
        $ctx->{current_timestamp} = $start;
        $ctx->{current_timestamp_end} = $end;
        my @entries = MT::Entry->load({ created_on => [ $start, $end ],
                                        blog_id => $blog->id,
                                        status => MT::Entry::RELEASE() },
                                      { range => { created_on => 1 } });
        $ctx->stash('entries', \@entries);
    } elsif ($at eq 'Category') {
        my $cat;
        unless ($cat = $param{Category}) {
            return $mt->error($mt->translate(
                "Building category archives, but no category provided."));
        }
        require MT::Placement;
        $ctx->stash('archive_category', $cat);
        my @entries = MT::Entry->load({ blog_id => $blog->id,
                                        status => MT::Entry::RELEASE() },
                         { 'join' => [ 'MT::Placement', 'entry_id',
                                     { category_id => $cat->id } ] });
        $ctx->stash('entries', \@entries);
    }

    my $fmgr = $blog->file_mgr;
    my $arch_root = $blog->archive_path;
    return $mt->error($mt->translate("You did not set your Local Archive Path"))
        unless $arch_root;

    ## For each mapping, we need to rebuild the entries we loaded above in
    ## the particular template map, and write it to the specified archive
    ## file template.
    require MT::Template;
    for my $map (@map) {
        my $file = File::Spec->catfile($arch_root, $map->{__saved_output_file});
        my $tmpl = $mt->{__cached_templates}{$map->template_id};
        unless ($tmpl) {
            $tmpl = MT::Template->load($map->template_id);
            if ($mt->{cache_templates}) {
                $mt->{__cached_templates}{$tmpl->id} = $tmpl;
            }
        }

        defined(my $html = $tmpl->build($ctx, \%cond)) or
            return $mt->error($mt->translate(
                "Building entry '[_1]' failed: [_2]",
                $entry->title, $tmpl->errstr));

        ## Untaint. We have to assume that we can trust the user's setting of
        ## the archive_path, and nothing else is based on user input.
        ($file) = $file =~ /(.+)/s;

        ## First check whether the content is actually changed. If not,
        ## we won't update the published file, so as not to modify the mtime.
        $done->{$map->{__saved_output_file}}++, next
            unless $fmgr->content_is_updated($file, \$html);

        ## Determine if we need to build directory structure, and build it
        ## if we do. DirUmask determines directory permissions.
        my $path = dirname($file);
        $path =~ s!/$!!;  ## OS X doesn't like / at the end in mkdir().
        unless ($fmgr->exists($path)) {
            $fmgr->mkpath($path)
                or return $mt->error($mt->translate(
                    "Error making path '[_1]': [_2]", $path, $fmgr->errstr));
        }

        ## By default we write all data to temp files, then rename the temp
        ## files to the real files (an atomic operation). Some users don't
        ## like this (requires too liberal directory permissions). So we
        ## have a config option to turn it off (NoTempFiles).
        my $use_temp_files = !$mt->{cfg}->NoTempFiles;
        my $temp_file = $use_temp_files ? "$file.new" : $file;
        defined($fmgr->put_data($html, $temp_file))
            or return $mt->error($mt->translate(
                "Writing to '[_1]' failed: [_2]", $temp_file, $fmgr->errstr));
        if ($use_temp_files) {
            $fmgr->rename($temp_file, $file)
                or return $mt->error($mt->translate(
                    "Renaming tempfile '[_1]' failed: [_2]",
                    $temp_file, $fmgr->errstr));
        }
        $done->{$map->{__saved_output_file}}++;
    }
    1;
}

sub rebuild_indexes {
    my $mt = shift;
    my %param = @_;
    require MT::Template;
    require MT::Template::Context;
    require MT::Entry;
    my $blog;
    unless ($blog = $param{Blog}) {
        my $blog_id = $param{BlogID};
        $blog = MT::Blog->load($blog_id) or
            return $mt->error($mt->translate("Load of blog '[_1]' failed: [_2]",
                $blog_id, MT::Blog->errstr));
    }
    return 1 if $blog->is_dynamic;
    my $iter;
    if (my $tmpl = $param{Template}) {
        my $i = 0;
        $iter = sub { $i++ < 1 ? $tmpl : undef };
    } else {
        $iter = MT::Template->load_iter({ type => 'index',
            blog_id => $blog->id });
    }
    local *FH;
    my $site_root = $blog->site_path;
    return $mt->error($mt->translate("You did not set your Local Site Path"))
        unless $site_root;
    my $fmgr = $blog->file_mgr;
    while (my $tmpl = $iter->()) {
        ## Skip index templates that the user has designated not to be
        ## rebuilt automatically. We need to do the defined-ness check
        ## because we added the flag in 2.01, and for templates saved
        ## before that time, the rebuild_me flag will be undefined. But
        ## we assume that these templates should be rebuilt, since that
        ## was the previous behavior.
        next if !$param{Force} &&
                defined $tmpl->rebuild_me && !$tmpl->rebuild_me;

        my $ctx = MT::Template::Context->new;
        my $html = $tmpl->build($ctx);
        return $mt->error( $tmpl->errstr ) unless defined $html;
        my $index = $tmpl->outfile
            or return $mt->error($mt->translate(
                "Template '[_1]' does not have an Output File.", $tmpl->name));
        unless (File::Spec->file_name_is_absolute($index)) {
            $index = File::Spec->catfile($site_root, $index);
        }
        ## Untaint. We have to assume that we can trust the user's setting of
        ## the site_path and the template outfile.
        ($index) = $index =~ /(.+)/s;

        ## First check whether the content is actually changed. If not,
        ## we won't update the published file, so as not to modify the mtime.
        next unless $fmgr->content_is_updated($index, \$html);

        ## Update the published file.
        my $use_temp_files = !$mt->{cfg}->NoTempFiles;
        my $temp_file = $use_temp_files ? "$index.new" : $index;
        defined($fmgr->put_data($html, $temp_file))
            or return $mt->error($mt->translate(
                "Writing to '[_1]' failed: [_2]", $temp_file, $fmgr->errstr));
        if ($use_temp_files) {
            $fmgr->rename($temp_file, $index)
                or return $mt->error($mt->translate(
                    "Renaming tempfile '[_1]' failed: [_2]",
                    $temp_file, $fmgr->errstr));
        }
    }
    1;
}

sub ping {
    my $mt = shift;
    my %param = @_;
    my $blog;
    unless ($blog = $param{Blog}) {
        my $blog_id = $param{BlogID};
        $blog = MT::Blog->load($blog_id) or
            return $mt->error(
                $mt->translate("Load of blog '[_1]' failed: [_2]",
                    $blog_id, MT::Blog->errstr));
    }

    my(@res);

    my $send_updates = 1;
    if (exists $param{OldStatus}) {
        ## If this is a new entry (!$old_status) OR the status was previously
        ## set to draft, and is now set to publish, send the update pings.
        my $old_status = $param{OldStatus};
        if ($old_status && $old_status eq MT::Entry::RELEASE()) {
            $send_updates = 0;
        }
    }

    if ($send_updates) {
        ## Send update pings.
        my @updates = $mt->update_ping_list($blog);
        for my $url (@updates) {
            require MT::XMLRPC;
            if (MT::XMLRPC->ping_update('weblogUpdates.ping', $blog, $url)) {
                push @res, { good => 1, url => $url, type => "update" };
            } else {
                push @res, { good => 0, url => $url, type => "update",
                             error => MT::XMLRPC->errstr };
            }
        }
        if ($blog->mt_update_key) {
            require MT::XMLRPC;
            if (MT::XMLRPC->mt_ping($blog)) {
                push @res, { good => 1, url => $mt->{cfg}->MTPingURL,
                             type => "update" };
            } else {
                push @res, { good => 0, url => $mt->{cfg}->MTPingURL,
                             type => "update", error => MT::XMLRPC->errstr };
            }
        }
    }

    ## Send TrackBack pings.
    if (my $entry = $param{Entry}) {
        my $pings = $entry->to_ping_url_list;

        my %pinged = map { $_ => 1 } @{ $entry->pinged_url_list };
        my $cats = $entry->categories;
        for my $cat (@$cats) {
            push @$pings, grep !$pinged{$_}, @{ $cat->ping_url_list };
        }

        my $ua = MT->new_ua;

        ## Build query string to be sent on each ping.
        my @qs;
        push @qs, 'title=' . MT::Util::encode_url($entry->title);
        push @qs, 'url=' . MT::Util::encode_url($entry->permalink);
        push @qs, 'excerpt=' . MT::Util::encode_url($entry->get_excerpt);
        push @qs, 'blog_name=' . MT::Util::encode_url($blog->name);
        my $qs = join '&', @qs;

        for my $url (@$pings) {
            $url =~ s/^\s*//;
            $url =~ s/\s*$//;
            my $req;
            if ($url =~ /\?/) {
                $req = HTTP::Request->new(GET => $url . '&' . $qs);
            } else {
                $req = HTTP::Request->new(POST => $url);
                $req->content_type('application/x-www-form-urlencoded');
                $req->content($qs);
            }
            my $res = $ua->request($req);
            if (substr($res->code, 0, 1) eq '2') {
                my $c = $res->content;
                my($error, $msg) = $c =~
                    m!<error>(\d+).*<message>(.+?)</message>!s;
                if ($error) {
                    push @res, { good => 0, url => $url, type => 'trackback',
                                 error => $msg };
                } else {
                    push @res, { good => 1, url => $url, type => 'trackback' };
                }
            } else {
                push @res, { good => 0, url => $url, type => 'trackback',
                             error => "HTTP error: " . $res->status_line };
            }
        }
    }
    \@res;
}

sub ping_and_save {
    my $mt = shift;
    my %param = @_;
    if (my $entry = $param{Entry}) {
        my $results = $mt->ping(@_) or return;
        my %still_ping;
        my $pinged = $entry->pinged_url_list;
        for my $res (@$results) {
            next if $res->{type} ne 'trackback';
            if (!$res->{good}) {
                $still_ping{ $res->{url} } = 1;
            } else {
                push @$pinged, $res->{url};
            }
        }
        $entry->pinged_urls(join "\n", @$pinged);
        $entry->to_ping_urls(join "\n", keys %still_ping);
        $entry->save or return $mt->error($entry->errstr);
        return $results;
    }
    1;
}

sub needs_ping {
    my $mt = shift;
    my %param = @_;
    my $blog = $param{Blog};
    my $entry = $param{Entry};
    return unless $entry->status == MT::Entry::RELEASE();
    my $old_status = $param{OldStatus};
    my %list;
    ## If this is a new entry (!$old_status) OR the status was previously
    ## set to draft, and is now set to publish, send the update pings.
    if (!$old_status || $old_status ne MT::Entry::RELEASE()) {
        my @updates = $mt->update_ping_list($blog);
        @list{ @updates } = (1) x @updates;
        $list{$mt->{cfg}->MTPingURL} = 1 if $blog && $blog->mt_update_key;
    }
    if ($entry) {
        @list{ @{ $entry->to_ping_url_list } } = ();
        my %pinged = map { $_ => 1 } @{ $entry->pinged_url_list };
        my $cats = $entry->categories;
        for my $cat (@$cats) {
            @list{ grep !$pinged{$_}, @{ $cat->ping_url_list } } = ();
        }
    }
    my @list = keys %list;
    return unless @list;
    \@list;
}

sub update_ping_list {
    my $mt = shift;
    my($blog) = @_;
    my @updates;
    if ($blog->ping_weblogs) {
        push @updates, $mt->{cfg}->WeblogsPingURL;
    }
    if ($blog->ping_blogs) {
        push @updates, $mt->{cfg}->BlogsPingURL;
    }
    if (my $others = $blog->ping_others) {
        push @updates, split /\r?\n/, $others;
    }
    my %updates;
    for my $url (@updates) {
        for ($url) {
            s/^\s*//; s/\s*$//;
        }
        next unless $url =~ /\S/;
        $updates{$url}++;
    }
    keys %updates;
}

{
    my $LH;
    sub set_language {
        require MT::L10N;
        $LH = MT::L10N->get_handle($_[1]);
    }

    sub translate {
        my $this = shift;
        $LH->maketext(@_);
    }

    sub translate_templatized {
        my $mt = shift;
        my($text) = @_;
        $text =~ s!<MT_TRANS ([^>]+)>!
            my($msg, %args) = ($1);
            while ($msg =~ /(\w+)\s*=\s*(["'])(.*?)\2/g) {
                $args{$1} = $3;
            }
            $args{params} = '' unless defined $args{params};
            my @p = map MT::Util::decode_html($_),
                    split /\s*%%\s*/, $args{params};
            $mt->translate($args{phrase}, @p);
        !ge;
        $text;
    }

    sub current_language { $LH->language_tag }
    sub language_handle { $LH }
}

sub supported_languages {
    my $mt = shift;
    require MT::L10N;
    require File::Basename;
    ## Determine full path to lib/MT/L10N directory...
    my $lib = 
        File::Spec->catdir(File::Basename::dirname($INC{'MT/L10N.pm'}), 'L10N');
    ## ... From that, determine full path to extlib/MT/L10N.
    ## To do that, we look for the last instance of the string 'lib'
    ## in $lib and replace it with 'extlib'. reverse is a nice tricky
    ## way of doing that.
    (my $extlib = reverse $lib) =~ s!bil!biltxe!;
    $extlib = reverse $extlib;
    my @dirs = ( $lib, $extlib );
    my %langs;
    for my $dir (@dirs) {
        opendir DH, $dir or next;
        for my $f (readdir DH) {
            my($tag) = $f =~ /^(\w+)\.pm$/;
            next unless $tag;
            my $lh = MT::L10N->get_handle($tag);
            $langs{$lh->language_tag} = $lh->language_name;
        }
        closedir DH;
    } 
    \%langs;
}

sub add_text_filter {
    my $mt = shift;
    my($key, $cfg) = @_;
    $cfg->{label} ||= $key;
    return $mt->error("No executable code") unless $cfg->{on_format};
    $Text_filters{$key} = $cfg;
}

sub all_text_filters { \%Text_filters }

sub apply_text_filters {
    my $mt = shift;
    my($str, $filters, @extra) = @_;
    for my $filter (@$filters) {
        next unless $Text_filters{$filter};
        $str = $Text_filters{$filter}{on_format}->($str, @extra);
    }
    $str;
}

sub new_ua {
    my $class = shift;
    require LWP::UserAgent;
    my $cfg = MT::ConfigMgr->instance;
    if (my $localaddr = $cfg->PingInterface) {
        @LWP::Protocol::http::EXTRA_SOCK_OPTS = (
              LocalAddr => $localaddr,
              Reuse => 1 );
    }
    my $ua = LWP::UserAgent->new;
    $ua->max_size(100_000) if $ua->can('max_size');
    $ua->agent('MovableType/' . MT->VERSION);
    $ua->timeout($cfg->PingTimeout);
    if (my $proxy = $cfg->PingProxy) {
        $ua->proxy(http => $proxy);
        my @domains = split(/,\s*/, $cfg->PingNoProxy);
        $ua->no_proxy(@domains);
    }
    $ua;        
}

1;
__END__

=head1 NAME

MT - Movable Type

=head1 SYNOPSIS

    use MT;
    my $mt = MT->new;
    $mt->rebuild(BlogID => 1)
        or die $mt->errstr;

=head1 DESCRIPTION

The I<MT> class is the main high-level rebuilding/pinging interface in the
Movable Type library. It handles all rebuilding operations. It does B<not>
handle any of the application functionality--for that, look to I<MT::App> and
I<MT::App::CMS>, both of which subclass I<MT> to handle application requests.

=head1 USAGE

I<MT> has the following interface. On failure, all methods return C<undef>
and set the I<errstr> for the object or class (depending on whether the
method is an object or class method, respectively); look below at the section
L<ERROR HANDLING> for more information.

=head2 MT->new( %args )

Constructs a new I<MT> instance and returns that object. Returns C<undef>
on failure.

I<new> will also read your F<mt.cfg> file (provided that it can find it--if
you find that it can't, take a look at the I<Config> directive, below). It
will also initialize the chosen object driver; the default is the C<DBM>
object driver.

I<%args> can contain:

=over 4

=item * Config

Path to the F<mt.cfg> file.

If you do not specify a path, I<MT> will try to find your F<mt.cfg> file
in the current working directory.

=back

=head2 $mt->rebuild( %args )

Rebuilds your entire blog, indexes and archives; or some subset of your blog,
as specified in the arguments.

I<%args> can contain:

=over 4

=item * Blog

An I<MT::Blog> object corresponding to the blog that you would like to
rebuild.

Either this or C<BlogID> is required.

=item * BlogID

The ID of the blog that you would like to rebuild.

Either this or C<Blog> is required.

=item * ArchiveType

The archive type that you would like to rebuild. This should be one of the
following values: C<Individual>, C<Daily>, C<Weekly>, C<Monthly>, or
C<Category>.

This argument is optional; if not provided, all archive types will be rebuilt.

=item * EntryCallback

A callback that will be called for each entry that is rebuilt. If provided,
the value should be a subroutine reference; the subroutine will be handed
the I<MT::Entry> object for the entry that is about to be rebuilt. You could
use this to keep a running log of which entry is being rebuilt, for example:

    $mt->rebuild(
              BlogID => $blog_id,
              EntryCallback => sub { print $_[0]->title, "\n" },
          );

Or to provide a status indicator:

    use MT::Entry;
    my $total = MT::Entry->count({ blog_id => $blog_id });
    my $i = 0;
    local $| = 1;
    $mt->rebuild(
              BlogID => $blog_id,
              EntryCallback => sub { printf "%d/%d\r", ++$i, $total },
          );
    print "\n";

This argument is optional; by default no callbacks are executed.

=item * NoIndexes

By default I<rebuild> will rebuild the index templates after rebuilding all
of the entries; if you do not want to rebuild the index templates, set the
value for this argument to a true value.

This argument is optional.

=item * Limit

Limit the number of entries to be rebuilt to the last C<N> entries in the
blog. For example, if you set this to C<20> and do not provide an offset (see
L<Offset>, below), the 20 most recent entries in the blog will be rebuilt.

This is only useful if you are rebuilding C<Individual> archives.

This argument is optional; by default all entries will be rebuilt.

=item * Offset

When used with C<Limit>, specifies the entry at which to start rebuilding
your individual entry archives. For example, if you set this to C<10>, and
set a C<Limit> of C<5> (see L<Limit>, above), entries 10-14 (inclusive) will
be rebuilt. The offset starts at C<0>, and the ordering is reverse
chronological.

This is only useful if you are rebuilding C<Individual> archives, and if you
are using C<Limit>.

This argument is optional; by default all entries will be rebuilt, starting
at the first entry.

=back

=head2 $mt->rebuild_entry( %args )

Rebuilds a particular entry in your blog (and its dependencies, if specified).

I<%args> can contain:

=over 4

=item * Entry

An I<MT::Entry> object corresponding to the object you would like to rebuild.

This argument is required.

=item * Blog

An I<MT::Blog> object corresponding to the blog to which the I<Entry> belongs.

This argument is optional; if not provided, the I<MT::Blog> object will be
loaded in I<rebuild_entry> from the I<$entry-E<gt>blog_id> column of the
I<MT::Entry> object passed in. If you already have the I<MT::Blog> object
loaded, however, it makes sense to pass it in yourself, as it will skip one
small step in I<rebuild_entry> (loading the object).

=item * BuildDependencies

Saving an entry can have effects on other entries; so after saving, it is
often necessary to rebuild other entries, to reflect the changes onto all
of the affected archive pages, indexes, etc.

If you supply this parameter with a true value, I<rebuild_indexes> will
rebuild: the archives for the next and previous entries, chronologically;
all of the index templates; the archives for the next and previous daily,
weekly, and monthly archives.

=back

=head2 $mt->rebuild_indexes( %args )

Rebuilds all of the index templates in your blog, or just one, if you use
the I<Template> argument (below). Only rebuilds templates that are set to
be rebuilt automatically, unless you use the I<Force> (below).

I<%args> can contain:

=over 4

=item * Blog

An I<MT::Blog> object corresponding to the blog whose indexes you would like
to rebuild.

Either this or C<BlogID> is required.

=item * BlogID

The ID of the blog whose indexes you would like to rebuild.

Either this or C<Blog> is required.

=item * Template

An I<MT::Template> object specifying the index template to rebuild; if you use
this argument, I<only> this index template will be rebuilt.

Note that if the template that you specify here is set to not rebuild
automatically, you I<must> specify the I<Force> argument in order to force it
to be rebuilt.

=item * Force

A boolean flag specifying whether or not to rebuild index templates who have
been marked not to be rebuilt automatically.

The default is C<0> (do not rebuild such templates).

=back

=head2 $mt->ping( %args )

Sends all configured XML-RPC pings as a way of notifying other community
sites that your blog has been updated.

I<%args> can contain:

=over 4

=item * Blog

An I<MT::Blog> object corresponding to the blog for which you would like to
send the pings.

Either this or C<BlogID> is required.

=item * BlogID

The ID of the blog for which you would like to send the pings.

Either this or C<Blog> is required.

=back

=head2 $mt->set_language($tag)

Loads the localization plugin for the language specified by I<$tag>, which
should be a valid and supported language tag--see I<supported_languages> to
obtain a list of supported languages.

The language is set on a global level, and affects error messages and all
text in the administration system.

This method can be called as either a class method or an object method; in
other words,

    MT->set_language($tag)

will also work. However, the setting will still be global--it will not be
specified to the I<$mt> object.

The default setting--set when I<MT::new> is called--is U.S. English. If a
I<DefaultLanguage> is set in F<mt.cfg>, the default is then set to that
language.

=head2 $mt->translate($str)

Translates I<$str> into the currently-set language (set by I<set_language>),
and returns the translated string.

=head2 $mt->current_language

Returns the language tag for the currently-set language.

=head2 MT->supported_languages

Returns a reference to an associative array mapping language tags to their
proper names. For example:

    use MT;
    my $langs = MT->supported_languages;
    print map { $_ . " => " . $langs->{$_} . "\n" } keys %$langs;

=head2 MT->add_text_filter($key, \%options)

Adds a text filter with the short name I<$key> and the options in
I<\%options>.

The text filter will be added to MT's list of text filtering options in
the new/edit entry screen, and will be used for filtering all of the entry
fields, if the user has enabled filtering for those fields in the template
(for example, by default the entry body and extended text are both run
through the filter, but the excerpt is not).

I<$key> should be a lower-case identifier containing only
alphanumerics and C<_> (that is, matching C</\w+/>). Since I<$key> is
stored as the filter name on a per-entry basis, it B<should not change>.
(In other words, don't call if I<foo> in one version and I<foo_bar> in
the next, if the filter does the same thing in each version.)

The flip side of this, though, is that if your filter acts differently
from one version to the next, you B<should> change I<$key>, and you
should also change the filename of your plugin, so that the old
implementation--which may be associated with all of the entries in the user's
system--still works as usual. For example, if your C<foo> plugin changes
semantics drastically so that paragraph breaks are represented as two
C<E<lt>br /E<gt>> tags, rather than C<E<lt>pE<gt>> tags, you should change
the key of the new version to C<foo_2> (for example), and the filename to
F<foo_2.pl>.

I<%options> can contain:

=over 4

=item * label

The short-but-descriptive label for the filter. This will be displayed in
the Movable Type UI as the name of the text filter.

=item * on_format

A reference to a subroutine that will be executed to filter a string of
text. The subroutine will always receive one argument, the string of text to
filter, and should return the filtered string. In some cases--for example,
when called while building a template--the subroutine will receive a
second argument, the I<MT::Template::Context> object handling the build.

See the example below.

=item * docs

The URL (or filename) of a document containing documentation on your filter.
This will be displayed in a popup window when the user selects your filter
on the New/Edit Entry screen, then clicks the Help link (C<(?)>).

If the value is a full URL (starting with C<http://>), the popup window
will open with that URL; otherwise, it is treated as a filename, assumed to
be in the user's F<docs> folder.

=back

Here's an example of adding a text filter for Wiki formatting, using the
I<Text::WikiFormat> CPAN module:

    MT->add_text_filter(wiki => {
        label => 'Wiki',
        on_format => sub {
            require Text::WikiFormat;
            Text::WikiFormat::format($_[0]);
        },
        docs => 'http://www.foo.com/mt/wiki.html',
    });

=head2 MT->apply_text_filters($str, \@filters)

Applies the set of filters I<\@filters> to the string I<$str> and returns
the result (the filtered string).

I<\@filters> should be a reference to an array of filter keynames--these
are the short names passed in as the first argument to I<add_text_filter>.
I<$str> should be a scalar string to be filtered.

If one of the filters listed in I<\@filters> is not found in the list of
registered filters (that is, filters added through I<add_text_filter>),
it will be skipped silently. Filters are executed in the order in which they
appear in I<\@filters>.

As it turns out, the I<MT::Entry::text_filters> method returns a reference
to the list of text filters to be used for that entry. So, for example, to
use this method to apply filters to the main entry text for an entry
I<$entry>, you would use

    my $out = MT->apply_text_filters($entry->text, $entry->text_filters);

=head2 MT->VERSION

Returns the version of MT (including any beta/alpha designations).

=head2 MT->version_number

Returns the numeric version of MT (without any beta/alpha designations).
For example, if I<VERSION> returned C<2.5b1>, I<version_number> would
return C<2.5>.

=head1 ERROR HANDLING

On an error, all of the above methods return C<undef>, and the error message
can be obtained by calling the method I<errstr> on the class or the object
(depending on whether the method called was a class method or an instance
method).

For example, called on a class name:

    my $mt = MT->new or die MT->errstr;

Or, called on an object:

    $mt->rebuild(BlogID => $blog_id)
        or die $mt->errstr;

=head1 LICENSE

Please see the file F<LICENSE> in the Movable Type distribution.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, MT is Copyright 2001-2003 Six Apart.
ben@movabletype.org, and Mena Trott, mena@movabletype.org. All rights
reserved.

=cut
