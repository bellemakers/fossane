# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Context.pm,v 1.186 2003/05/28 07:48:24 btrott Exp $

package MT::Template::Context;
use strict;

use MT::Util qw( start_end_day start_end_week start_end_month
                 munge_comment archive_file_for
                 format_ts offset_time_list first_n_words dirify get_entry
                 encode_html encode_js remove_html wday_from_ts days_in
                 spam_protect encode_php encode_url decode_html encode_xml
                 decode_xml );
use MT::ConfigMgr;
use MT::Request;
use MT::ErrorHandler;
@MT::Template::Context::ISA = qw( MT::ErrorHandler );

use constant FALSE => -99999;
use Exporter;
*import = \&Exporter::import;
use vars qw( @EXPORT );
@EXPORT = qw( FALSE );

use vars qw( %Global_handlers %Global_filters );
sub add_tag {
    my $class = shift;
    my($name, $code) = @_;
    $Global_handlers{$name} = { code => $code, is_container => 0 };
}
sub add_container_tag {
    my $class = shift;
    my($name, $code) = @_;
    $Global_handlers{$name} = { code => $code, is_container => 1 };
}
sub add_conditional_tag {
    my $class = shift;
    my($name, $condition) = @_;
    $Global_handlers{$name} = { code => sub {
        if ($condition->(@_)) {
            return _hdlr_pass_tokens(@_);
        } else {
            return '';
        }
    }, is_container => 1 };
}
sub add_global_filter {
    my $class = shift;
    my($name, $code) = @_;
    $Global_filters{$name} = $code;
}

sub new {
    my $class = shift;
    my $ctx = bless {}, $class;
    $ctx->init(@_);
}

sub init {
    my $ctx = shift;
    $ctx->init_default_handlers;
    for my $tag (keys %Global_handlers) {
        my $arg = $Global_handlers{$tag}{is_container} ?
            [ $Global_handlers{$tag}{code}, 1 ] : $Global_handlers{$tag}{code};
        $ctx->register_handler($tag => $arg);
    }
    $ctx;
}

sub init_default_handlers {
    my $ctx = shift;
    $ctx->register_handler(Else => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(CGIPath => \&_hdlr_cgi_path);
    $ctx->register_handler(CGIRelativeURL => \&_hdlr_cgi_relative_url);
    $ctx->register_handler(StaticWebPath => \&_hdlr_static_path);
    $ctx->register_handler(CommentScript => \&_hdlr_comment_script);
    $ctx->register_handler(TrackbackScript => \&_hdlr_trackback_script);
    $ctx->register_handler(SearchScript => \&_hdlr_search_script);
    $ctx->register_handler(XMLRPCScript => \&_hdlr_xmlrpc_script);
    $ctx->register_handler(Date => \&_hdlr_sys_date);
    $ctx->register_handler(Version => \&_hdlr_mt_version);
    $ctx->register_handler(PublishCharset => \&_hdlr_publish_charset);

    $ctx->register_handler(Blogs => [ \&_hdlr_blogs, 1 ]);
    $ctx->register_handler(BlogID => \&_hdlr_blog_id);
    $ctx->register_handler(BlogName => \&_hdlr_blog_name);
    $ctx->register_handler(BlogDescription => \&_hdlr_blog_description);
    $ctx->register_handler(BlogURL => \&_hdlr_blog_url);
    $ctx->register_handler(BlogArchiveURL => \&_hdlr_blog_archive_url);
    $ctx->register_handler(BlogRelativeURL => \&_hdlr_blog_relative_url);
    $ctx->register_handler(BlogSitePath => \&_hdlr_blog_site_path);
    $ctx->register_handler(BlogHost => \&_hdlr_blog_host);
    $ctx->register_handler(BlogTimezone => \&_hdlr_blog_timezone);
    $ctx->register_handler(BlogEntryCount => \&_hdlr_blog_entry_count);
    $ctx->register_handler(BlogCommentCount => \&_hdlr_blog_comment_count);
    $ctx->register_handler(BlogCCLicenseURL => \&_hdlr_blog_cc_license_url);
    $ctx->register_handler(BlogCCLicenseImage => \&_hdlr_blog_cc_license_image);
    $ctx->register_handler(CCLicenseRDF => \&_hdlr_cc_license_rdf);
    $ctx->register_handler(BlogIfCCLicense => [ \&_hdlr_blog_if_cc_license, 1 ]);

    $ctx->register_handler(Entries => [ \&_hdlr_entries, 1 ]);
    $ctx->register_handler(EntriesHeader => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(EntriesFooter => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(EntryID => \&_hdlr_entry_id);
    $ctx->register_handler(EntryTitle => \&_hdlr_entry_title);
    $ctx->register_handler(EntryStatus => \&_hdlr_entry_status);
    $ctx->register_handler(EntryFlag => \&_hdlr_entry_flag);
    $ctx->register_handler(EntryCategory => \&_hdlr_entry_category);
    $ctx->register_handler(EntryCategories => [ \&_hdlr_entry_categories, 1 ]);
    $ctx->register_handler(EntryBody => \&_hdlr_entry_body);
    $ctx->register_handler(EntryMore => \&_hdlr_entry_more);
    $ctx->register_handler(EntryExcerpt => \&_hdlr_entry_excerpt);
    $ctx->register_handler(EntryKeywords => \&_hdlr_entry_keywords);
    $ctx->register_handler(EntryLink => \&_hdlr_entry_link);
    $ctx->register_handler(EntryPermalink => \&_hdlr_entry_permalink);
    $ctx->register_handler(EntryAuthor => \&_hdlr_entry_author);
    $ctx->register_handler(EntryAuthorEmail => \&_hdlr_entry_author_email);
    $ctx->register_handler(EntryAuthorURL => \&_hdlr_entry_author_url);
    $ctx->register_handler(EntryAuthorLink => \&_hdlr_entry_author_link);
    $ctx->register_handler(EntryAuthorNickname => \&_hdlr_entry_author_nick);
    $ctx->register_handler(EntryDate => \&_hdlr_date);
    $ctx->register_handler(EntryCommentCount => \&_hdlr_entry_comments);
    $ctx->register_handler(EntryTrackbackCount => \&_hdlr_entry_ping_count);
    $ctx->register_handler(EntryIfExtended => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(EntryIfAllowComments => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(EntryIfCommentsOpen => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(EntryIfAllowPings => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(EntryTrackbackLink => \&_hdlr_entry_tb_link);
    $ctx->register_handler(EntryTrackbackData => \&_hdlr_entry_tb_data);
    $ctx->register_handler(EntryTrackbackID => \&_hdlr_entry_tb_id);
    $ctx->register_handler(EntryPrevious => [ \&_hdlr_entry_previous, 1 ]);
    $ctx->register_handler(EntryNext => [ \&_hdlr_entry_next, 1 ]);

    $ctx->register_handler(DateHeader => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(DateFooter => [ \&_hdlr_pass_tokens, 1 ]);

    $ctx->register_handler(ArchivePrevious => [ \&_hdlr_archive_prev_next, 1 ]);
    $ctx->register_handler(ArchiveNext => [ \&_hdlr_archive_prev_next, 1 ]);

    $ctx->register_handler(Include => \&_hdlr_include);
    $ctx->register_handler(Link => \&_hdlr_link);

    $ctx->register_handler(ErrorMessage => \&_hdlr_error_message);

    $ctx->register_handler(GetVar => \&_hdlr_var);
    $ctx->register_handler(SetVar => \&_hdlr_var);

    $ctx->register_handler(Comments => [ \&_hdlr_comments, 1 ]);
    $ctx->register_handler(CommentID => \&_hdlr_comment_id);
    $ctx->register_handler(CommentEntryID => \&_hdlr_comment_entry_id);
    $ctx->register_handler(CommentName => \&_hdlr_comment_author);
    $ctx->register_handler(CommentIP => \&_hdlr_comment_ip);
    $ctx->register_handler(CommentAuthor => \&_hdlr_comment_author);
    $ctx->register_handler(CommentAuthorLink => \&_hdlr_comment_author_link);
    $ctx->register_handler(CommentEmail => \&_hdlr_comment_email);
    $ctx->register_handler(CommentURL => \&_hdlr_comment_url);
    $ctx->register_handler(CommentBody => \&_hdlr_comment_body);
    $ctx->register_handler(CommentOrderNumber => \&_hdlr_comment_order_num);
    $ctx->register_handler(CommentDate => \&_hdlr_date);
    $ctx->register_handler(CommentEntry => [ \&_hdlr_comment_entry, 1 ]);
    $ctx->register_handler(CommentPreviewAuthor => \&_hdlr_comment_author);
    $ctx->register_handler(CommentPreviewIP => \&_hdlr_comment_ip);
    $ctx->register_handler(CommentPreviewAuthorLink =>
        \&_hdlr_comment_author_link);
    $ctx->register_handler(CommentPreviewEmail => \&_hdlr_comment_email);
    $ctx->register_handler(CommentPreviewURL => \&_hdlr_comment_url);
    $ctx->register_handler(CommentPreviewBody => \&_hdlr_comment_body);
    $ctx->register_handler(CommentPreviewDate => \&_hdlr_date);
    $ctx->register_handler(CommentPreviewState => \&_hdlr_comment_prev_state);
    $ctx->register_handler(CommentPreviewIsStatic =>
        \&_hdlr_comment_prev_static);

    $ctx->register_handler(ArchiveList => [ \&_hdlr_archives, 1 ]);
    $ctx->register_handler(ArchiveLink => \&_hdlr_archive_link);
    $ctx->register_handler(ArchiveTitle => \&_hdlr_archive_title);
    $ctx->register_handler(ArchiveCount => \&_hdlr_archive_count);
    $ctx->register_handler(ArchiveDate => \&_hdlr_date);
    $ctx->register_handler(ArchiveDateEnd => \&_hdlr_archive_date_end);
    $ctx->register_handler(ArchiveCategory => \&_hdlr_archive_category);

    $ctx->register_handler(ImageURL => \&_hdlr_image_url);
    $ctx->register_handler(ImageWidth => \&_hdlr_image_width);
    $ctx->register_handler(ImageHeight => \&_hdlr_image_height);

    $ctx->register_handler(Calendar => [ \&_hdlr_calendar, 1 ]);
    $ctx->register_handler(CalendarDay => \&_hdlr_calendar_day);
    $ctx->register_handler(CalendarCellNumber => \&_hdlr_calendar_cell_num);
    $ctx->register_handler(CalendarDate => \&_hdlr_date);
    $ctx->register_handler(CalendarWeekHeader => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(CalendarWeekFooter => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(CalendarIfBlank => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(CalendarIfToday => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(CalendarIfEntries => [ \&_hdlr_pass_tokens, 1 ]);
    $ctx->register_handler(CalendarIfNoEntries => [ \&_hdlr_pass_tokens, 1 ]);

    $ctx->register_handler(Categories => [ \&_hdlr_categories, 1 ]);
    $ctx->register_handler(CategoryID => \&_hdlr_category_id);
    $ctx->register_handler(CategoryLabel => \&_hdlr_category_label);
    $ctx->register_handler(CategoryDescription => \&_hdlr_category_desc);
    $ctx->register_handler(CategoryArchiveLink => \&_hdlr_category_archive);
    $ctx->register_handler(CategoryCount => \&_hdlr_category_count);
    $ctx->register_handler(CategoryTrackbackLink => \&_hdlr_category_tb_link);

    $ctx->register_handler(GoogleSearch => [ \&_hdlr_google_search, 1 ]);
    $ctx->register_handler(GoogleSearchResult => \&_hdlr_google_search_result);

    $ctx->register_handler(Pings => [ \&_hdlr_pings, 1 ]);
    $ctx->register_handler(PingsSent => [ \&_hdlr_pings_sent, 1 ]);
    $ctx->register_handler(PingsSentURL => \&_hdlr_pings_sent_url);
    $ctx->register_handler(PingTitle => \&_hdlr_ping_title);
    $ctx->register_handler(PingID => \&_hdlr_ping_id);
    $ctx->register_handler(PingURL => \&_hdlr_ping_url);
    $ctx->register_handler(PingExcerpt => \&_hdlr_ping_excerpt);
    $ctx->register_handler(PingBlogName => \&_hdlr_ping_blog_name);
    $ctx->register_handler(PingIP => \&_hdlr_ping_ip);
    $ctx->register_handler(PingDate => \&_hdlr_date);
}

sub sanitize_on {
    $_[0]->{'sanitize'} = 1 unless exists $_[0]->{'sanitize'};
}

sub post_process_handler {
    sub {
        my($ctx, $args, $str) = @_;
        if ($args) {
            my %local_args = %$args;
            for my $arg (keys %local_args) {
                if (my $code = $Global_filters{$arg}) {
                    $str = $code->($str, $args->{$arg}, $ctx);
                    delete $local_args{$arg};
                }
            }
            if (my $f = $local_args{'filters'}) {
                $str = MT->apply_text_filters($str, [ split /\s*,\s*/, $f ], $ctx);
            }
            if ($local_args{'decode_html'}) {
                $str = decode_html($str);
            }
            if ($local_args{'decode_xml'}) {
                $str = decode_xml($str);
            }
            if ($local_args{'remove_html'}) {
                $str = remove_html($str);
            }
            if ($local_args{'dirify'}) {
                $str = dirify($str);
            }
            if (my $spec = $local_args{'sanitize'}) {
                require MT::Sanitize;
                if ($spec eq '1') {
                    $spec = $ctx->stash('blog')->sanitize_spec ||
                            MT::ConfigMgr->instance->GlobalSanitizeSpec;
                }
                $str = MT::Sanitize->sanitize($str, $spec);
            }
            if ($local_args{'encode_html'}) {
                $str = encode_html($str);
            }
            if ($local_args{'encode_xml'}) {
                $str = encode_xml($str);
            }
            if ($local_args{'encode_js'}) {
                $str = encode_js($str);
            }
            if (my $meth = $local_args{'encode_php'}) {
                $str = encode_php($str, $meth);
            }
            if ($local_args{'encode_url'}) {
                $str = encode_url($str);
            }
            if ($local_args{upper_case}) {
                $str = uc($str);
            }
            if ($local_args{lower_case}) {
                $str = lc($str);
            }
            if (my $len = $local_args{space_pad}) {
                $str = sprintf "%${len}s", $str;
            }
            if (my $len = $local_args{zero_pad}) {
                $str = sprintf "%0${len}s", $str;
            }
            if (my $format = $local_args{'sprintf'}) {
                $str = sprintf($format, $str);
            }
            if (my $len = $local_args{trim_to}) {
                $str = substr $str, 0, $len if $len < length($str);
            }
        }
        $str;
    }
}

sub stash {
    my $ctx = shift;
    my $key = shift;
    $ctx->{__stash}->{$key} = shift if @_;
    $ctx->{__stash}->{$key};
}

sub register_handler { $_[0]->{__handlers}{$_[1]} = $_[2] }
sub handler_for      {
    my $v = $_[0]->{__handlers}{$_[1]};
    ref($v) eq 'ARRAY' ? @$v : $v
}

sub _hdlr_include {
    my($arg, $cond) = @_[1,2];
    if (my $tmpl_name = $arg->{module}) {
        require MT::Template;
        my $tmpl = MT::Template->load({ name => $tmpl_name,
                                        blog_id => $_[0]->stash('blog_id') })
            or return $_[0]->error(MT->translate(
                "Can't find included template module '[_1]'", $tmpl_name ));
        return $tmpl->build($_[0], $cond);
    } elsif (my $file = $arg->{file}) {
        my $blog = $_[0]->stash('blog');
        my @paths = ($file, map File::Spec->catfile($_, $file),
                            $blog->site_path, $blog->archive_path);
        my $path;
        for my $p (@paths) {
            $path = $p, last if -e $p && -r _;
        }
        return $_[0]->error(MT->translate(
            "Can't find included file '[_1]'", $file )) unless $path;
        local *FH;
        open FH, $path
            or return $_[0]->error(MT->translate(
                "Error opening included file '[_1]': [_2]", $path, $! ));
        my $c = '';
        local $/; $c = <FH>;
        close FH;
        return $c;
    }
}

sub _hdlr_link {
    my($ctx, $arg, $cond) = @_;
    if (my $tmpl_name = $arg->{template}) {
        require MT::Template;
        my $tmpl = MT::Template->load({ name => $tmpl_name,
                                        type => 'index',
                                        blog_id => $_[0]->stash('blog_id') })
            or return $ctx->error(MT->translate(
                "Can't find template '[_1]'", $tmpl_name ));
        my $site_url = $ctx->stash('blog')->site_url;
        $site_url .= '/' unless $site_url =~ m!/$!;
        return $site_url . $tmpl->outfile;
    } elsif (my $entry_id = $arg->{entry_id}) {
        require MT::Entry;
        my $entry = MT::Entry->load($entry_id)
            or return $ctx->error(MT->translate(
                "Can't find entry '[_1]'", $entry_id ));
        return $entry->permalink;
    }
}

sub _hdlr_mt_version {
    require MT;
    MT->VERSION;
}

sub _hdlr_publish_charset {
    MT::ConfigMgr->instance->PublishCharset || 'iso-8859-1';
}

sub _hdlr_error_message {
    my $err = $_[0]->stash('error_message');
    defined $err ? $err : '';
}

sub _hdlr_var {
    my($ctx, $args) = @_;
    my $tag = $ctx->stash('tag');
    return $ctx->error(MT->translate(
        "You used a [_1] tag without any arguments.", "<MT$tag>" ))
        unless keys %$args && $args->{name};
    if ($tag eq 'SetVar') {
        my $val = defined $args->{value} ? $args->{value} : '';
        $ctx->{__stash}{vars}{$args->{name}} = $val;
    } else {
        return $ctx->{__stash}{vars}{$args->{name}};
    }
    '';
}

sub _hdlr_cgi_path {
    my $path = MT::ConfigMgr->instance->CGIPath;
    $path .= '/' unless $path =~ m!/$!;
    $path;
}
sub _hdlr_cgi_relative_url {
    my $url = MT::ConfigMgr->instance->CGIPath;
    $url .= '/' unless $url =~ m!/$!;
    if ($url =~ m!^https?://[^/]+(/.*)$!) {
        return $1;
    } else {
        return $url;
    }
}
sub _hdlr_static_path {
    my $path = MT::ConfigMgr->instance->StaticWebPath;
    $path .= '/' unless $path =~ m!/$!;
    $path;
}
sub _hdlr_comment_script { MT::ConfigMgr->instance->CommentScript }
sub _hdlr_trackback_script { MT::ConfigMgr->instance->TrackbackScript }
sub _hdlr_search_script { MT::ConfigMgr->instance->SearchScript }
sub _hdlr_xmlrpc_script { MT::ConfigMgr->instance->XMLRPCScript }

sub _hdlr_blogs {
    my($ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    require MT::Blog;
    my $iter = MT::Blog->load_iter;
    my $res = '';
    while (my $blog = $iter->()) {
        local $ctx->{__stash}{blog} = $blog;
        local $ctx->{__stash}{blog_id} = $blog->id;
        defined(my $out = $builder->build($ctx, $tokens, $cond))
            or return $ctx->error($builder->errstr);
        $res .= $out;
    }
    $res;
}
sub _hdlr_blog_id { $_[0]->stash('blog')->id }
sub _hdlr_blog_name { $_[0]->stash('blog')->name }
sub _hdlr_blog_description {
    my $d = $_[0]->stash('blog')->description;
    defined $d ? $d : '';
}
sub _hdlr_blog_url {
    my $url = $_[0]->stash('blog')->site_url;
    $url .= '/' unless $url =~ m!/$!;
    $url;
}
sub _hdlr_blog_site_path {
    my $path = $_[0]->stash('blog')->site_path;
    $path .= '/' unless $path =~ m!/$!;
    $path;
}
sub _hdlr_blog_archive_url { $_[0]->stash('blog')->archive_url }
sub _hdlr_blog_relative_url {
    my $host = $_[0]->stash('blog')->site_url;
    if ($host =~ m!^https?://[^/]+(/.*)$!) {
        return $1;
    } else {
        return '';
    }
}
sub _hdlr_blog_timezone {
    my $so = $_[0]->stash('blog')->server_offset;
    my $no_colon = $_[1]->{no_colon};
    sprintf "%s%02d%s00", $so < 0 ? '-' : '+', abs($so), $no_colon ? '' : ':';
}
sub _hdlr_blog_host {
    my $host = $_[0]->stash('blog')->site_url;
    if ($host =~ m!^https?://([^/]+)/!) {
        return $1;
    } else {
        return '';
    }
}
sub _hdlr_blog_entry_count {
    my $blog_id = $_[0]->stash('blog')->id;
    require MT::Entry;
    scalar MT::Entry->count({ blog_id => $blog_id,
                              status => MT::Entry::RELEASE() });
}
sub _hdlr_blog_comment_count {
    my $blog_id = $_[0]->stash('blog')->id;
    require MT::Comment;
    scalar MT::Comment->count({ blog_id => $blog_id });
}

sub _hdlr_blog_cc_license_url {
    $_[0]->stash('blog')->cc_license_url;
}
sub _hdlr_blog_cc_license_image {
    my $cc = $_[0]->stash('blog')->cc_license or return;
    "http://creativecommons.org/images/public/" .
        ($cc eq 'pd' ? 'norights' : 'somerights');
}
sub _hdlr_cc_license_rdf {
    my($ctx, $arg) = @_;
    my $blog = $ctx->stash('blog');
    my $cc = $blog->cc_license or return;
    my $cc_url = $blog->cc_license_url;
    my $rdf = <<RDF;
<!--
<rdf:RDF xmlns="http://web.resource.org/cc/"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
RDF
    ## SGML comments cannot contain double hyphens, so we convert
    ## any double hyphens to single hyphens.
    my $strip_hyphen = sub {
        (my $s = $_[0]) =~ tr/\-//s;
        $s;
    };
    if (my $entry = $ctx->stash('entry')) {
        $rdf .= <<RDF;
<Work rdf:about="@{[ $entry->permalink ]}">
<dc:title>@{[ encode_xml($strip_hyphen->($entry->title)) ]}</dc:title>
<dc:description>@{[ encode_xml($strip_hyphen->(_hdlr_entry_excerpt(@_))) ]}</dc:description>
<dc:creator>@{[ encode_xml($strip_hyphen->($entry->author ? $entry->author->name : '')) ]}</dc:creator>
<dc:date>@{[ _hdlr_date($_[0], { 'format' => "%Y-%m-%dT%H:%M:%S" }) .
             _hdlr_blog_timezone($_[0]) ]}</dc:date>
<license rdf:resource="$cc_url" />
</Work>
RDF
    } else {
        $rdf .= <<RDF;
<Work rdf:about="@{[ $blog->site_url ]}">
<dc:title>@{[ encode_xml($strip_hyphen->($blog->name)) ]}</dc:title>
<dc:description>@{[ encode_xml($strip_hyphen->($blog->description)) ]}</dc:description>
<license rdf:resource="$cc_url" />
</Work>
RDF
    }
    $rdf .= MT::Util::cc_rdf($cc) . "</rdf:RDF>\n-->\n";
    $rdf;
}
sub _hdlr_blog_if_cc_license {
    $_[0]->stash('blog')->cc_license ? _hdlr_pass_tokens(@_) : '';
}

sub _hdlr_entries {
    my($ctx, $args, $cond) = @_;
    require MT::Entry;
    my @entries;
    my $blog_id = $ctx->stash('blog_id');
    my($cat, $author, $saved_entry_stash);
    if (my $cat_name = $args->{category}) {
        require MT::Category;
        ## If this is a boolean lookup (like "Foo AND Bar"), we have to
        ## special-case the search. Then we stick the resulting list of
        ## entries into the stash so that it can be filtered using the
        ## mechanism below.
        if ($cat_name =~ /\s+(?:AND|OR)\s+/) {
            return $ctx->error(MT->translate(
                "You can't use both AND and OR in the same expression ([_1]).",
                $cat_name ))
                if $cat_name =~ /AND/ && $cat_name =~ /OR/;
            my @cats = split /\s+(?:AND|OR)\s+/, $cat_name;
            my %entries;
            require MT::Placement;
            for my $name (@cats) {
                my $cat = MT::Category->load({ label => $name,
                                               blog_id => $blog_id })
                    or return $ctx->error(MT->translate(
                        "No such category '[_1]'", $name ));
                my @place = MT::Placement->load({ category_id => $cat->id });
                for my $place (@place) {
                    $entries{$place->entry_id}++;
                }
            }
            my $is_and = $cat_name =~ /AND/;
            my $count = @cats;
            my @ids = $is_and ? grep { $entries{$_} == $count } keys %entries :
                                keys %entries;
            $saved_entry_stash = $ctx->{__stash}{entries} || [];
            if (@$saved_entry_stash) {
                my %temp = map { $_ => 1 } @ids;
                @entries = grep { $temp{$_->id} } @$saved_entry_stash;
            } else {
                for my $entry_id (@ids) {
                    my $entry = MT::Entry->load($entry_id);
                    push @entries, $entry
                        if $entry->status == MT::Entry::RELEASE();
                }
            }
            $ctx->{__stash}{entries} = \@entries;
            delete $args->{category};
        } else {
            $cat = MT::Category->load({ label => $cat_name,
                blog_id => $blog_id })
                or return $ctx->error(MT->translate(
                    "No such category '[_1]'", $cat_name));
        }
    }
    if (my $author_name = $args->{author}) {
        require MT::Author;
        $author = MT::Author->load({ name => $author_name }) or
            return $ctx->error(MT->translate(
                "No such author '[_1]'", $author_name ));
    }
    my $no_resort = 0;
    if (my $entries = $ctx->stash('entries')) {
        @entries = @$entries;
        if (%$args) {
            my $n = $args->{lastn};
            ## If lastn is defined, we need to make sure that the list of
            ## entries is in descending order.
            if ($n) {
                @entries = sort { $b->created_on cmp $a->created_on }
                           @entries;
            }
            my $off = $args->{offset} || 0;
            my($i, $j) = (0, 0);
            my @tmp;
            for my $e (@entries) {
                next if $off && $j++ < $off;
                last if $n && $i >= $n;
                next unless !$cat || $e->is_in_category($cat);
                next unless !$author || $e->author_id == $author->id;
                push @tmp, $e;
                $i++;
            }
            @entries = @tmp;
        }
    } elsif (%$args) {
        my %terms = ( blog_id => $blog_id, status => MT::Entry::RELEASE() );
        $terms{author_id} = $author->id if $author;
        my %args;
        if ($cat) {
            require MT::Placement;
            $args{'join'} = [ 'MT::Placement', 'entry_id',
                              { category_id => $cat->id }, { unique => 1 } ];
        }
        if (my $last = $args->{lastn}) {
            $args{'sort'} = 'created_on';
            $args{direction} = 'descend';
            $args{limit} = $last;
            $args{offset} = $args->{offset} if $args->{offset};
        } elsif (my $days = $args->{days}) {
            my @ago = offset_time_list(time - 3600 * 24 * $days,
                $ctx->stash('blog_id'));
            my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
                $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
            $terms{created_on} = [ $ago ];
            %args = ( range => { created_on => 1 } );
        } elsif (my $n = $args->{recently_commented_on}) {
            $args{'join'} = [ 'MT::Comment', 'entry_id',
                { blog_id => $blog_id },
                { 'sort' => 'created_on',
                  direction => 'descend',
                  unique => 1,
                  limit => $n } ];
            $no_resort = 1;
        }
        @entries = MT::Entry->load(\%terms, \%args);
    } else {
        my $days = $ctx->stash('blog')->days_on_index;
        my @ago = offset_time_list(time - 3600 * 24 * $days,
            $ctx->stash('blog_id'));
        my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
            $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
        @entries = MT::Entry->load({ blog_id => $blog_id,
                                     created_on => [ $ago ],
                                     status => MT::Entry::RELEASE() },
            { range => { created_on => 1 } });
    }
    my $res = '';
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    unless ($no_resort) {
        my $so = $args->{sort_order} || $ctx->stash('blog')->sort_order_posts;
        my $col = $args->{sort_by} || 'created_on';
        @entries = $so eq 'ascend' ?
            sort { $a->$col() cmp $b->$col() } @entries :
            sort { $b->$col() cmp $a->$col() } @entries;
    }
    my($last_day, $next_day) = ('00000000') x 2;
    my $i = 0;
    for my $e (@entries) {
        local $ctx->{__stash}{entry} = $e;
        local $ctx->{current_timestamp} = $e->created_on;
        my $this_day = substr $e->created_on, 0, 8;
        my $next_day = $this_day;
        my $footer = 0;
        if (defined $entries[$i+1]) {
            $next_day = substr($entries[$i+1]->created_on, 0, 8);
            $footer = $this_day ne $next_day;
        } else { $footer++ }
        my $out = $builder->build($ctx, $tok, {
            %$cond,
            DateHeader => ($this_day ne $last_day),
            DateFooter => $footer,
            EntryIfExtended => $e->text_more ? 1 : 0,
            EntryIfAllowComments => $e->allow_comments,
            EntryIfCommentsOpen => $e->allow_comments eq '1',
            EntryIfAllowPings => $e->allow_pings,
            EntriesHeader => !$i,
            EntriesFooter => !defined $entries[$i+1],
        });
        $last_day = $this_day;
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
        $i++;
    }

    ## Restore a saved entry stash. This is basically emulating "local",
    ## which we can't use, because the local would be buried too far down
    ## in a conditional.
    if ($saved_entry_stash) {
        if (!@$saved_entry_stash) {
            delete $ctx->{__stash}{entries};
        } else {
            $ctx->{__stash}{entries} = $saved_entry_stash;
        }
    }
    $res;
}

sub _no_entry_error {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of an entry; " .
        "perhaps you mistakenly placed it outside of an 'MTEntries' container?",
        $_[1]));
}
sub _hdlr_entry_body {
    my $arg = $_[1];
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryBody');
    my $text = $e->text;
    $text = '' unless defined $text;
    my $convert_breaks = exists $arg->{convert_breaks} ?
        $arg->{convert_breaks} :
            defined $e->convert_breaks ? $e->convert_breaks :
                $_[0]->stash('blog')->convert_paras;
    if ($convert_breaks) {
        my $filters = $e->text_filters;
        push @$filters, '__default__' unless @$filters;
        $text = MT->apply_text_filters($text, $filters, $_[0]);
    }
    return first_n_words($text, $arg->{words}) if exists $arg->{words};
    $text;
}
sub _hdlr_entry_more {
    my $arg = $_[1];
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryMore');
    my $text = $e->text_more;
    $text = '' unless defined $text;
    my $convert_breaks = exists $arg->{convert_breaks} ?
        $arg->{convert_breaks} :
            defined $e->convert_breaks ? $e->convert_breaks :
                $_[0]->stash('blog')->convert_paras;
    if ($convert_breaks) {
        my $filters = $e->text_filters;
        push @$filters, '__default__' unless @$filters;
        $text = MT->apply_text_filters($text, $filters, $_[0]);
    }
    $text;
}
sub _hdlr_entry_title {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryTitle');
    defined $e->title ? $e->title : '';
}
sub _hdlr_entry_status {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryStatus');
    MT::Entry::status_text($e->status);
}
sub _hdlr_entry_flag {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryFlag');
    my $flag = $_[1]->{flag}
        or return $_[0]->error(MT->translate(
            'You used <$MTEntryFlag$> without a flag.' ));
    my $v = $e->$flag();
    ## The logic here: when we added the convert_breaks flag, we wanted it
    ## to default to checked, because we added it in 2.0, and people had
    ## previously been using the global convert_paras setting, so we needed
    ## that to be used if it wasn't defined. So that's the reason for the
    ## second test (else) (should we be looking at blog->convert_paras?).
    ## When we added allow_pings, we only want this to be applied if
    ## explicitly checked.
    if ($flag eq 'allow_pings') {
        return defined $v ? $v : 0;
    } else {
        return defined $v ? $v : 1;
    }
}
sub _hdlr_entry_excerpt {
    my($ctx, $args) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryExcerpt');
    if (my $excerpt = $e->excerpt) {
        return $excerpt unless $args->{convert_breaks};
        my $filters = $e->text_filters;
        push @$filters, '__default__' unless @$filters;
        return MT->apply_text_filters($excerpt, $filters, $ctx);
    } elsif ($args->{no_generate}) {
        return '';
    }
    my $words = $ctx->stash('blog')->words_in_excerpt;
    $words = 40 unless defined $words && $words ne '';
    my $excerpt = _hdlr_entry_body($ctx, { words => $words, %$args });
    return '' unless $excerpt;
    $excerpt . '...';
}
sub _hdlr_entry_keywords {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryKeywords');
    defined $e->keywords ? $e->keywords : '';
}
sub _hdlr_entry_author {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryAuthor');
    my $a = $e->author;
    $a ? $a->name || '' : '';
}
sub _hdlr_entry_author_nick {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryAuthorNickname');
    my $a = $e->author;
    $a ? $a->nickname || '' : '';
}
sub _hdlr_entry_author_email {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MT' . $_[0]->stash('tag'));
    my $a = $e->author;
    return '' unless $a && defined $a->email;
    $_[1] && $_[1]->{'spam_protect'} ? spam_protect($a->email) : $a->email;
}
sub _hdlr_entry_author_url {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MT' . $_[0]->stash('tag'));
    my $a = $e->author;
    $a ? $a->url || '' : '';
}
sub _hdlr_entry_author_link {
    my($ctx, $args) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MT' . $ctx->stash('tag'));
    my $a = $e->author;
    return '' unless $a;
    my $name = $a->name || '';
    my $show_email = 1 unless exists $args->{show_email};
    my $show_url = 1 unless exists $args->{show_url};
    if ($show_url && $a->url) {
        return sprintf qq(<a target="_blank" href="%s">%s</a>), $a->url, $name;
    } elsif ($show_email && $a->email) {
        my $str = "mailto:" . $a->email;
        $str = spam_protect($str) if $args->{'spam_protect'};
        return sprintf qq(<a href="%s">%s</a>), $str, $name;
    } else {
        return $name;
    }
}
sub _hdlr_entry_id {
    my $args = $_[1];
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryID');
    $args && $args->{pad} ? (sprintf "%06d", $e->id) : $e->id;
}
sub _hdlr_entry_tb_link {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryTrackbackLink');
    require MT::Trackback;
    my $tb = MT::Trackback->load({ entry_id => $e->id })
        or return '';
    my $cfg = MT::ConfigMgr->instance;
    my $path = $cfg->CGIPath;
    $path .= '/' unless $path =~ m!/$!;
    $path . $cfg->TrackbackScript . '/' . $tb->id;
}
sub _hdlr_entry_tb_data {
    my($ctx, $args) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryTrackbackData');
    require MT::Trackback;
    my $tb = MT::Trackback->load({ entry_id => $e->id })
        or return '';
    return '' if $tb->is_disabled;
    my $cfg = MT::ConfigMgr->instance;
    my $path = $cfg->CGIPath;
    $path .= '/' unless $path =~ m!/$!;
    $path .= $cfg->TrackbackScript . '/' . $tb->id;
    my $url;
    if (my $at = $_[0]->{current_archive_type}) {
        $url = $e->archive_url($at);
        $url .= '#' . sprintf("%06d", $e->id)
            unless $at eq 'Individual';
    } else {
        $url = $e->permalink;
    }
    my $rdf = '';
    my $comment_wrap = defined $args->{comment_wrap} ?
        $args->{comment_wrap} : 1;
    $rdf .= "<!--\n" if $comment_wrap;
    ## SGML comments cannot contain double hyphens, so we convert
    ## any double hyphens to single hyphens.
    my $strip_hyphen = sub {
        (my $s = $_[0]) =~ tr/\-//s;
        $s;
    };
    $rdf .= <<RDF;
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:trackback="http://madskills.com/public/xml/rss/module/trackback/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
<rdf:Description
    rdf:about="$url"
    trackback:ping="$path"
    dc:title="@{[ encode_xml($strip_hyphen->($e->title)) ]}"
    dc:identifier="$url"
    dc:subject="@{[ encode_xml($e->category ? $e->category->label : '') ]}"
    dc:description="@{[ encode_xml($strip_hyphen->(_hdlr_entry_excerpt(@_))) ]}"
    dc:creator="@{[ encode_xml(_hdlr_entry_author(@_)) ]}"
    dc:date="@{[ _hdlr_date($_[0], { 'format' => "%Y-%m-%dT%H:%M:%S" }) .
                 _hdlr_blog_timezone($_[0]) ]}" />
</rdf:RDF>
RDF
    $rdf .= "-->\n" if $comment_wrap;
    $rdf;
}
sub _hdlr_entry_tb_id {
    my($ctx, $args) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryTrackbackID');
    require MT::Trackback;
    my $tb = MT::Trackback->load({ entry_id => $e->id })
        or return '';
    $tb->id;
}
sub _hdlr_entry_link {
    my $args = $_[1];
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryLink');
    my $arch = $_[0]->stash('blog')->archive_url;
    $arch .= '/' unless $arch =~ m!/$!;
    $arch . $e->archive_file($args ? $args->{archive_type} : ());
}
sub _hdlr_entry_permalink {
    my $args = $_[1];
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryLink');
    $e->permalink($args ? $args->{archive_type} : ());
}
sub _hdlr_entry_category {
    my($ctx) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryCategory');
    my $cat = $e->category;
    $cat ? $cat->label : '';
}

sub _hdlr_entry_categories {
    my($ctx, $args, $cond) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryCategories');
    my $cats = $e->categories;
    return '' unless $cats && @$cats;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my @res;
    for my $cat (@$cats) {
        local $ctx->{__stash}->{category} = $cat;
        defined(my $out = $builder->build($ctx, $tokens, $cond))
            or return $ctx->error( $builder->errstr );
        push @res, $out;
    }
    my $sep = $args->{glue} || '';
    join $sep, @res;
}

sub _hdlr_entry_comments {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryCommentCount');
    $e->comment_count;
}
sub _hdlr_entry_ping_count {
    my $e = $_[0]->stash('entry')
        or return $_[0]->_no_entry_error('MTEntryTrackbackCount');
    $e->ping_count;
}
sub _hdlr_entry_previous {
    my($ctx, $args, $cond) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryPrevious');
    my $prev = $e->previous(1);
    my $res = '';
    if ($prev) {
        my $builder = $ctx->stash('builder');
        local $ctx->{__stash}->{entry} = $prev;
        local $ctx->{current_timestamp} = $prev->created_on;
        my %cond = %$cond;
        $cond{EntryIfAllowComments} = $prev->allow_comments;
        $cond{EntryIfCommentsOpen} = $prev->allow_comments eq '1';
        $cond{EntryIfAllowPings} = $prev->allow_pings;
        $cond{EntryIfExtended} = $prev->text_more ? 1 : 0;
        my $out = $builder->build($ctx, $ctx->stash('tokens'), \%cond);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
    }
    $res;
}
sub _hdlr_entry_next {
    my($ctx, $args, $cond) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryNext');
    my $next = $e->next(1);
    my $res = '';
    if ($next) {
        my $builder = $ctx->stash('builder');
        local $ctx->{__stash}->{entry} = $next;
        local $ctx->{current_timestamp} = $next->created_on;
        my %cond = %$cond;
        $cond{EntryIfAllowComments} = $next->allow_comments;
        $cond{EntryIfCommentsOpen} = $next->allow_comments eq '1';
        $cond{EntryIfAllowPings} = $next->allow_pings;
        $cond{EntryIfExtended} = $next->text_more ? 1 : 0;
        my $out = $builder->build($ctx, $ctx->stash('tokens'), \%cond);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
    }
    $res;
}

sub _hdlr_pass_tokens {
    my($ctx, $args, $cond) = @_;
    $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond);
}

sub _hdlr_sys_date {
    my $args = $_[1];
    my @ts = offset_time_list(time, $_[0]->stash('blog_id'));
    $args->{ts} = sprintf "%04d%02d%02d%02d%02d%02d",
        $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
    _hdlr_date($_[0], $args);
}

sub _hdlr_date {
    my $args = $_[1];
    my $ts = $args->{ts} || $_[0]->{current_timestamp};
    my $tag = $_[0]->stash('tag');
    return $_[0]->error(MT->translate(
        "You used an [_1] tag without a date context set up.", "MT$tag" ))
        unless defined $ts;
    format_ts($args->{'format'}, $ts, $_[0]->stash('blog'), $args->{language});
}

sub _no_comment_error {
    return $_[0]->error(MT->translate(
        "You used an '[_1]' tag outside of the context of a comment; " .
        "perhaps you mistakenly placed it outside of an 'MTComments' " .
        "container?", $_[1] ));
}
sub _hdlr_comments {
    my($ctx, $args, $cond) = @_;
    my $blog_id = $ctx->stash('blog_id');
    my @comments;
    my $so = $args->{sort_order} || $ctx->stash('blog')->sort_order_comments;
    ## If there is a "lastn" arg, then we need to check if there is an entry
    ## in context. If so, grab the N most recent comments for that entry;
    ## otherwise, grab the N most recent comments for the entire blog.
    if (my $n = $args->{lastn}) {
        if (my $e = $ctx->stash('entry')) {
            ## Sort in descending order, then grab the first $n ($n most
            ## recent) comments.
            my $comments = $e->comments;
            @comments = $so eq 'ascend' ?
                sort { $a->created_on <=> $b->created_on } @$comments :
                sort { $b->created_on <=> $a->created_on } @$comments;
            my $max = $n - 1 > $#comments ? $#comments : $n - 1;
            @comments = $so eq 'ascend' ?
                @comments[$#comments-$max..$#comments] :
                @comments[0..$max];
        } else {
            require MT::Comment;
            @comments = MT::Comment->load({ blog_id => $blog_id },
                { 'sort' => 'created_on',
                  direction => 'descend',
                  limit => $n });
            @comments = $so eq 'ascend' ?
                sort { $a->created_on <=> $b->created_on } @comments :
                sort { $b->created_on <=> $a->created_on } @comments;
        }
    } else {
        my $e = $ctx->stash('entry')
            or return $_[0]->_no_entry_error('MTComments');
        my $comments = $e->comments;
        @comments = $so eq 'ascend' ?
            sort { $a->created_on <=> $b->created_on } @$comments :
            sort { $b->created_on <=> $a->created_on } @$comments;
    }
    my $html = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $i = 1;
    for my $c (@comments) {
        $ctx->stash('comment' => $c);
        local $ctx->{current_timestamp} = $c->created_on;
        $ctx->stash('comment_order_num', $i);
        my $out = $builder->build($ctx, $tokens, $cond);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $html .= $out;
        $i++;
    }
    $html;
}
sub _hdlr_comment_id {
    my $args = $_[1];
    my $c = $_[0]->stash('comment')
        or return $_[0]->_no_comment_error('MTCommentID');
    $args && $args->{pad} ? (sprintf "%06d", $c->id) : $c->id;
}
sub _hdlr_comment_entry_id {
    my $args = $_[1];
    my $c = $_[0]->stash('comment')
        or return $_[0]->_no_comment_error('MTCommentEntryID');
    $args && $args->{pad} ? (sprintf "%06d", $c->entry_id) : $c->entry_id;
}
sub _hdlr_comment_author {
    sanitize_on($_[1]);
    my $tag = $_[0]->stash('tag');
    my $c = $_[0]->stash($tag =~ /Preview/ ? 'comment_preview' : 'comment')
        or return $_[0]->_no_comment_error('MT' . $tag);
    my $a = defined $c->author ? $c->author : '';
    remove_html($a);
}
sub _hdlr_comment_ip {
    my $tag = $_[0]->stash('tag');
    my $c = $_[0]->stash($tag =~ /Preview/ ? 'comment_preview' : 'comment')
        or return $_[0]->_no_comment_error('MT' . $tag);
    defined $c->ip ? $c->ip : '';
}
sub _hdlr_comment_author_link {
    sanitize_on($_[1]);
    my($ctx, $args) = @_;
    my $tag = $ctx->stash('tag');
    my $c = $ctx->stash($tag =~ /Preview/ ? 'comment_preview' : 'comment')
        or return $ctx->_no_comment_error('MT' . $tag);
    my $name = $c->author;
    $name = '' unless defined $name;
    my $show_email = 1 unless exists $args->{show_email};
    my $show_url = 1 unless exists $args->{show_url};
    if ($show_url && $c->url) {
        my $url = remove_html($c->url);
        return sprintf qq(<a target="_blank" href="%s">%s</a>), $url, $name;
    } elsif ($show_email && $c->email) {
        my $email = remove_html($c->email);
        my $str = "mailto:" . $email;
        $str = spam_protect($str) if $args->{'spam_protect'};
        return sprintf qq(<a href="%s">%s</a>), $str, $name;
    } else {
        return $name;
    }
}
sub _hdlr_comment_email {
    sanitize_on($_[1]);
    my $tag = $_[0]->stash('tag');
    my $c = $_[0]->stash($tag =~ /Preview/ ? 'comment_preview' : 'comment')
        or return $_[0]->_no_comment_error('MT' . $tag);
    return '' unless defined $c->email;
    my $email = remove_html($c->email);
    $_[1] && $_[1]->{'spam_protect'} ? spam_protect($email) : $email;
}
sub _hdlr_comment_url {
    sanitize_on($_[1]);
    my $tag = $_[0]->stash('tag');
    my $c = $_[0]->stash($tag =~ /Preview/ ? 'comment_preview' : 'comment')
        or return $_[0]->_no_comment_error('MT' . $tag);
    my $url = defined $c->url ? $c->url : '';
    remove_html($url);
}
sub _hdlr_comment_body {
    my($ctx, $arg) = @_;
    sanitize_on($arg);
    my $tag = $ctx->stash('tag');
    my $c = $ctx->stash($tag =~ /Preview/ ? 'comment_preview' : 'comment')
        or return $ctx->_no_comment_error('MT' . $tag);
    my $blog = $ctx->stash('blog');
    my $t = defined $c->text ? $c->text : '';
    $t = munge_comment($t, $blog);
    my $convert_breaks = exists $arg->{convert_breaks} ?
        $arg->{convert_breaks} :
        $blog->convert_paras_comments;
    return $convert_breaks ?
        MT->apply_text_filters($t, $blog->comment_text_filters, $ctx) :
        $t;
}
sub _hdlr_comment_order_num { $_[0]->stash('comment_order_num') }
sub _hdlr_comment_prev_state { $_[0]->stash('comment_state') }
sub _hdlr_comment_prev_static {
    my $s = $_[0]->stash('comment_is_static');
    defined $s ? $s : ''
}
sub _hdlr_comment_entry {
    my($ctx, $args, $cond) = @_;
    my $c = $ctx->stash('comment')
        or return $ctx->_no_comment_error('MTCommentEntry');
    require MT::Entry;
    my $entry = MT::Entry->load($c->entry_id)
        or return '';
    local $ctx->{__stash}{entry} = $entry;
    local $ctx->{current_timestamp} = $entry->created_on;
    $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond);
}

## Archives

{
    my $cur;
    my %TypeHandlers = (
        Individual => {
            group_end => sub { 1 },
            section_title => sub { $_[1]->title },
            section_timestamp => sub { $_[1]->created_on },
        },

        Daily => {
            group_end => sub {
                my $sod = start_end_day($_[1]->created_on,
                    $_[0]->stash('blog'));
                my $end = !$cur || $sod == $cur ? 0 : 1;
                $cur = $sod;
                $end;
            },
            section_title => sub {
                my $start =
                    start_end_day($_[1]->created_on, $_[0]->stash('blog'));
                _hdlr_date($_[0], { ts => $start, 'format' => "%x" });
            },
            section_timestamp => sub {
                start_end_day($_[1]->created_on, $_[0]->stash('blog'))
            },
            helper => \&start_end_day,
        },

        Weekly => {
            group_end => sub {
                my $sow = start_end_week($_[1]->created_on,
                    $_[0]->stash('blog'));
                my $end = !$cur || $sow == $cur ? 0 : 1;
                $cur = $sow;
                $end;
            },
            section_title => sub {
                my($start, $end) =
                    start_end_week($_[1]->created_on, $_[0]->stash('blog'));
                _hdlr_date($_[0], { ts => $start, 'format' => "%x" }) .
                ' - ' .
                _hdlr_date($_[0], { ts => $end, 'format' => "%x" });
            },
            section_timestamp => sub {
                start_end_week($_[1]->created_on, $_[0]->stash('blog'))
            },
            helper => \&start_end_week,
        },

        Monthly => {
            group_end => sub {
                my $som = start_end_month($_[1]->created_on,
                    $_[0]->stash('blog'));
                my $end = !$cur || $som == $cur ? 0 : 1;
                $cur = $som;
                $end;
            },
            section_title => sub {
                my $start =
                    start_end_month($_[1]->created_on, $_[0]->stash('blog'));
                _hdlr_date($_[0], { ts => $start, 'format' => "%B %Y" });
            },
            section_timestamp => sub {
                start_end_month($_[1]->created_on, $_[0]->stash('blog'));
            },
            helper => \&start_end_month,
        },
    );

    sub _hdlr_archive_prev_next {
        my($ctx, $args, $cond) = @_;
        my $tag = $ctx->stash('tag');
        my $is_prev = $tag eq 'ArchivePrevious';
        my $ts = $ctx->{current_timestamp}
            or return $ctx->error(MT->translate(
               "You used an [_1] without a date context set up.", "<MT$tag>" ));
        my $at = $_[1]->{archive_type} || $ctx->{current_archive_type};
        return $ctx->error(MT->translate(
            "[_1] can be used only with Daily, Weekly, or Monthly archives.",
            "<MT$tag>" ))
            unless $at eq 'Daily' || $at eq 'Weekly' || $at eq 'Monthly';
        my $res = '';
        my @arg = ($ts, $ctx->stash('blog_id'), $at);
        push @arg, $is_prev ? 'previous' : 'next';
        my $helper = $TypeHandlers{$at}{helper};
        if (my $entry = get_entry(@arg)) {
            my $builder = $ctx->stash('builder');
            local $ctx->{__stash}->{entries} = [ $entry ];
            my($start, $end) = $helper->($entry->created_on);
            local $ctx->{current_timestamp} = $start;
            local $ctx->{current_timestamp_end} = $end;
            defined(my $out = $builder->build($ctx, $ctx->stash('tokens'),
                $cond))
                or return $ctx->error( $builder->errstr );
            $res .= $out;
        }
        $res;
    }

    sub _hdlr_archives {
        my($ctx, $args, $cond) = @_;
        $cur = undef;
        require MT::Entry;
        my $blog = $ctx->stash('blog');
        my $at = $blog->archive_type;
        return '' if !$at || $at eq 'None';
        if (my $arg_at = $args->{archive_type}) {
            my %at = map { $_ => 1 } split /,/, $at;
            unless ($at{$arg_at}) {
                return $ctx->error(MT->translate(
                  "The archive type specified in MTArchiveList ('[_1]') " .
                  "is not one of the chosen archive types in your blog " .
                  "configuration.", $arg_at ));
            }
            $at = $arg_at;
        } elsif ($blog->archive_type_preferred) {
            $at = $blog->archive_type_preferred;
        } else {
            $at = (split /,/, $at)[0];
        }
        ## If we are producing a Category archive list, don't bother to
        ## handle it here--instead hand it over to <MTCategories>.
        return _hdlr_categories(@_) if $at eq 'Category';
        local $ctx->{current_archive_type} = $at;
        my %args;
        if ($at eq 'Category') {
            $args{'sort'} = 'category_id';
        } else {
            $args{'sort'} = 'created_on';
            $args{direction} = 'descend';
        }
        my $group_end = $TypeHandlers{$at}{group_end};
        my $sec_ts = $TypeHandlers{$at}{section_timestamp};
        my $iter = MT::Entry->load_iter({ blog_id => $blog->id,
                                          status => MT::Entry::RELEASE() },
                                        \%args);
        my @entries;
        my $tokens = $ctx->stash('tokens');
        my $builder = $ctx->stash('builder');
        my $res = '';
        my $i = 0;
        my $n = $args->{lastn};
        while (my $entry = $iter->()) {
            if ($group_end->($ctx, $entry) && @entries) {
                local $ctx->{__stash}{entries} = \@entries;
                my($start, $end) = $sec_ts->($ctx, $entries[0]);
                local $ctx->{current_timestamp} = $start;
                local $ctx->{current_timestamp_end} = $end;
                defined(my $out = $builder->build($ctx, $tokens, $cond)) or
                    return $ctx->error( $builder->errstr );
                $res .= $out;
                @entries = ();    ## Reset entry list
                last if $n && $i++ >= $n-1;
            }
            push @entries, $entry;
        }
        if (@entries) {
            local $ctx->{__stash}{entries} = \@entries;
            my($start, $end) = $sec_ts->($ctx, $entries[0]);
            local $ctx->{current_timestamp} = $start;
            local $ctx->{current_timestamp_end} = $end;
            defined(my $out = $builder->build($ctx, $tokens)) or
                return $ctx->error( $builder->errstr );
            $res .= $out;
        }
        $res;
    }

    sub _hdlr_archive_title {
        ## Since this tag can be called from inside <MTCategories>,
        ## we need a way to map this tag to <$MTCategoryLabel$>.
        return _hdlr_category_label(@_) if $_[0]->{inside_mt_categories};

        my($ctx) = @_;
        my $entries = $ctx->stash('entries');
        if (!$entries && (my $e = $ctx->stash('entry'))) {
            push @$entries, $e;
        }
        my @entries;
        my $at = $ctx->{current_archive_type};
        if ($entries && ref($entries) eq 'ARRAY' && $at) {
            @entries = @$entries;
        } else {
            ## This situation arises every once in awhile. We have
            ## a date-based archive page, but no entries to go on it--this
            ## might happen, for example, if you have daily archives, and
            ## you post an entry, and then you change the status to draft.
            ## The page will be rebuilt in order to empty it, but in the
            ## process, there won't be any entries in $entries. So, we
            ## build a stub MT::Entry object and set the created_on date
            ## to the current timestamp (start of day/week/month).
            if ($at && $at =~ /^(Daily|Monthly|Weekly)$/) {
                my $e = MT::Entry->new;
                $e->created_on($ctx->{current_timestamp});
                @entries = ($e);
            } else {
                return $ctx->error(MT->translate(
                    "You used an [_1] tag outside of the proper context.",
                    '<$MTArchiveTitle$>' ));
            }
        }
        return '' unless @entries;
        if ($ctx->{current_archive_type} eq 'Category') {
            return $ctx->stash('archive_category')->label;
        } else {
            my $st = $TypeHandlers{$ctx->{current_archive_type}}{section_title};
            my $title = $st->($ctx, $entries[0]);
            defined $title ? $title : '';
        }
    }
}

sub _hdlr_archive_date_end {
    my($ctx) = @_;
    my $end = $ctx->{current_timestamp_end}
        or return $_[0]->error(MT->translate(
            "You used an [_1] tag outside of a Daily, Weekly, or Monthly " .
            "context.", '<$MTArchiveDateEnd$>' ));
    $_[1]{ts} = $end;
    _hdlr_date(@_);
}

sub _hdlr_archive_link {
    ## Since this tag can be called from inside <MTCategories>,
    ## we need a way to map this tag to <$MTCategoryArchiveLink$>.
    return _hdlr_category_archive(@_) if $_[0]->{inside_mt_categories};

    my($ctx) = @_;
    my $blog = $ctx->stash('blog');
    my $entries = $ctx->stash('entries');
    if (!$entries && (my $e = $ctx->stash('entry'))) {
        push @$entries, $e;
    }
    return $ctx->error(MT->translate(
        "You used an [_1] tag outside of the proper context.",
        '<$MTArchiveLink$>' ))
        unless $entries && ref($entries) eq 'ARRAY';
    my $entry = $entries->[0];
    my $at = $_[1]->{archive_type} || $ctx->{current_archive_type};
    my $arch = $blog->archive_url;
    $arch .= '/' unless $arch =~ m!/$!;
    $arch . archive_file_for($entry, $blog, $at);
}

sub _hdlr_archive_count {
    my $ctx = $_[0];
    if ($ctx->{inside_mt_categories}) {
        return _hdlr_category_count($ctx);
    } elsif (my $count = $ctx->stash('archive_count')) {
        return $count;
    } else {
        my $e = $_[0]->stash('entries');
        $e && ref($e) eq 'ARRAY' ? scalar @$e : 0;
    }
}

sub _hdlr_archive_category {
    ## Since this tag can be called from inside <MTCategories>,
    ## we need a way to map this tag to <$MTCategoryLabel$>.
    return _hdlr_category_label(@_) if $_[0]->{inside_mt_categories};

    my $cat = $_[0]->stash('archive_category');
    $cat ? $cat->label : '';
}

sub _hdlr_image_url { $_[0]->stash('image_url') }
sub _hdlr_image_width { $_[0]->stash('image_width') }
sub _hdlr_image_height { $_[0]->stash('image_height') }

sub _hdlr_calendar {
    my($ctx, $args, $cond) = @_;
    my $blog_id = $ctx->stash('blog_id');
    my($prefix);
    my @ts = offset_time_list(time, $blog_id);
    my $today = sprintf "%04d%02d", $ts[5]+1900, $ts[4]+1;
    if ($prefix = $args->{month}) {
        if ($prefix eq 'this') {
            my $ts = $ctx->{current_timestamp}
                or return $ctx->error(MT->translate(
                    "You used an [_1] tag without a date context set up.",
                    qq(<MTCalendar month="this">) ));
            $prefix = substr $ts, 0, 6;
        } elsif ($prefix eq 'last') {
            my $year = substr $today, 0, 4;
            my $month = substr $today, 4, 2;
            if ($month - 1 == 0) {
                $prefix = $year - 1 . "12";
            } else {
                $prefix = $year . $month - 1;
            }
        } else {
            return $ctx->error(MT->translate(
                "Invalid month format: must be YYYYMM" ))
                unless length($prefix) eq 6;
        }
    } else {
        $prefix = $today;
    }
    my($cat_name, $cat);
    if ($cat_name = $args->{category}) {
        require MT::Category;
        $cat = MT::Category->load({ label => $cat_name, blog_id => $blog_id })
            or return $ctx->error(MT->translate(
                "No such category '[_1]'", $cat_name ));
    } else {
        $cat_name = '';    ## For looking up cached calendars.
    }
    my $uncompiled = $ctx->stash('uncompiled');
    my $r = MT::Request->instance;
    my $calendar_cache = $r->cache('calendar');
    unless ($calendar_cache) {
        $r->cache('calendar', $calendar_cache = { });
    }
    if (exists $calendar_cache->{$prefix . $cat_name} &&
        $calendar_cache->{$prefix . $cat_name}{'uc'} eq $uncompiled) {
        return $calendar_cache->{$prefix . $cat_name}{output};
    }
    $today .= sprintf "%02d", $ts[3];
    my($start, $end) = start_end_month($prefix);
    my($y, $m) = unpack 'A4A2', $prefix;
    my $days_in_month = days_in($m, $y);
    my $pad_start = wday_from_ts($y, $m, 1);
    my $pad_end = 6 - wday_from_ts($y, $m, $days_in_month);
    require MT::Entry;
    my $iter = MT::Entry->load_iter({ blog_id => $blog_id,
                                      created_on => [ $start, $end ],
                                      status => MT::Entry::RELEASE() },
        { range => { created_on => 1 },
          'sort' => 'created_on',
          direction => 'ascend', });
    my @left;
    my $res = '';
    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $iter_drained = 0;
    for my $day (1..$pad_start+$days_in_month+$pad_end) {
        my $is_padding =
            $day < $pad_start+1 || $day > $pad_start+$days_in_month;
        my($this_day, @entries) = ('');
        local($ctx->{__stash}{entries}, $ctx->{__stash}{calendar_day},
              $ctx->{current_timestamp});
        local $ctx->{__stash}{calendar_cell} = $day;
        unless ($is_padding) {
            $this_day = $prefix . sprintf("%02d", $day - $pad_start);
            my $no_loop = 0;
            if (@left) {
                if (substr($left[0]->created_on, 0, 8) eq $this_day) {
                    @entries = @left;
                    @left = ();
                } else {
                    $no_loop = 1;
                }
            }
            unless ($no_loop || $iter_drained) {
                while (my $entry = $iter->()) {
                    next unless !$cat || $entry->is_in_category($cat);
                    my $e_day = substr $entry->created_on, 0, 8;
                    push(@left, $entry), last
                        unless $e_day eq $this_day;
                    push @entries, $entry;
                }
                $iter_drained++ unless @left;
            }
            $ctx->{__stash}{entries} = \@entries;
            $ctx->{current_timestamp} = $this_day . '000000';
            $ctx->{__stash}{calendar_day} = $day - $pad_start;
        }
        defined(my $out = $builder->build($ctx, $tokens, {
            %$cond,
            CalendarWeekHeader => ($day-1) % 7 == 0,
            CalendarWeekFooter => $day % 7 == 0,
            CalendarIfEntries => !$is_padding && scalar @entries,
            CalendarIfNoEntries => !$is_padding && !(scalar @entries),
            CalendarIfToday => ($today eq $this_day),
            CalendarIfBlank => $is_padding,
        })) or
            return $ctx->error( $builder->errstr );
        $res .= $out;
    }
    $calendar_cache->{$prefix . $cat_name} =
        { output => $res, 'uc' => $uncompiled };
    $res;
}

sub _hdlr_calendar_day {
    my $day = $_[0]->stash('calendar_day')
        or return $_[0]->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MTCalendarDay$>' ));
    $day;
}

sub _hdlr_calendar_cell_num {
    my $num = $_[0]->stash('calendar_cell')
        or return $_[0]->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MTCalendarCellNumber$>' ));
    $num;
}

sub _hdlr_categories {
    my($ctx, $args, $cond) = @_;
    my $blog_id = $ctx->stash('blog_id');
    require MT::Category;
    require MT::Placement;
    my $iter = MT::Category->load_iter({ blog_id => $blog_id },
        { 'sort' => 'label', direction => 'ascend' });
    my $res = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $needs_entries = ($ctx->stash('uncompiled') =~ /<\$?MTEntries/) ? 1 : 0;
    ## In order for this handler to double as the handler for
    ## <MTArchiveList archive_type="Category">, it needs to support
    ## the <$MTArchiveLink$> and <$MTArchiveTitle$> tags
    local $ctx->{inside_mt_categories} = 1;
    while (my $cat = $iter->()) {
        local $ctx->{__stash}{category} = $cat;
        local $ctx->{__stash}{entries};
        local $ctx->{__stash}{category_count};
        my @args = (
            { blog_id => $blog_id,
              status => MT::Entry::RELEASE() },
            { 'join' => [ 'MT::Placement', 'entry_id',
                          { category_id => $cat->id } ],
              'sort' => 'created_on',
              direction => 'descend', });
        if ($needs_entries) {
            my @entries = MT::Entry->load(@args);
            $ctx->{__stash}{entries} = \@entries;
            $ctx->{__stash}{category_count} = scalar @entries;
        } else {
            $ctx->{__stash}{category_count} = MT::Entry->count(@args);
        }
        next unless $ctx->{__stash}{category_count} || $args->{show_empty};
        defined(my $out = $builder->build($ctx, $tokens, $cond))
            or return $ctx->error( $builder->errstr );
        $res .= $out;
    }
    $res;
}

sub _hdlr_category_id {
    my $cat = $_[0]->stash('category')
        or return $_[0]->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MTCategoryID$>' ));
    $cat->id;
}

sub _hdlr_category_label {
    my $cat = $_[0]->stash('category')
        or return $_[0]->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MTCategoryLabel$>' ));
    defined $cat->label ? $cat->label : '';
}

sub _hdlr_category_desc {
    my $cat = ($_[0]->stash('category') || $_[0]->stash('archive_category'))
        or return $_[0]->error('You used <$MTCategoryDescription$> outside ' .
                               'of the proper context.');
    defined $cat->description ? $cat->description : '';
}

sub _hdlr_category_count {
    my($ctx) = @_;
    my $cat = $ctx->stash('category')
        or return $_[0]->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MTCategoryCount$>' ));
    my($count);
    unless ($count = $ctx->stash('category_count')) {
        require MT::Placement;
        $count = MT::Placement->count({ category_id => $cat->id });
    }
    $count;
}

sub _hdlr_category_archive {
    my $cat = $_[0]->stash('category')
        or return $_[0]->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MTCategoryArchiveLink$>' ));
    my $blog = $_[0]->stash('blog');
    my $at = $blog->archive_type;
    return $_[0]->error(MT->translate(
        '[_1] can be used only if you have enabled Category archives.',
        '<$MTCategoryArchiveLink$>' ))
            unless $at =~ /Category/;
    my $arch = $blog->archive_url;
    $arch .= '/' unless $arch =~ m!/$!;
    $arch . archive_file_for(undef, $blog, 'Category', $cat);
}

sub _hdlr_category_tb_link {
    my($ctx, $args) = @_;
    my $cat = $_[0]->stash('category') || $_[0]->stash('archive_category');
    if (!$cat) {
        my $cat_name = $args->{category}
            or return $ctx->error('<$MTCategoryTrackbackLink$> must be ' .
                "used in the context of a category, or with the 'category' " .
                "attribute to the tag.");
        require MT::Category;
        $cat = MT::Category->load({ label => $cat_name,
                                    blog_id => $ctx->stash('blog_id') })
            or return $ctx->error("No such category '$cat_name'");
    }
    require MT::Trackback;
    my $tb = MT::Trackback->load({ category_id => $cat->id })
        or return '';
    my $cfg = MT::ConfigMgr->instance;
    my $path = $cfg->CGIPath;
    $path .= '/' unless $path =~ m!/$!;
    $path . $cfg->TrackbackScript . '/' . $tb->id;
}

sub _hdlr_google_search {
    my($ctx, $args, $cond) = @_;
    my $query;
    my $blog = $ctx->stash('blog');
    if ($query = $args->{query}) {
    } elsif (my $url = $args->{related}) {
        $query = 'related:' . ($url eq '1' ? $blog->site_url : $url);
    } elsif ($args->{title}) {
        $query = $ctx->_hdlr_entry_title or return '';
    } elsif ($args->{excerpt}) {
        $query = $ctx->_hdlr_entry_excerpt or return '';
    } elsif ($args->{keywords}) {
        $query = $ctx->_hdlr_entry_keywords or return '';
    } else {
        return $ctx->error(MT->translate(
            'You used [_1] without a query.', '<MTGoogleSearch>' ));
    }
    my $key = $blog->google_api_key
        or return $ctx->error(MT->translate(
            'You need a Google API key to use [_1]', '<MTGoogleSearch>' ));
    my $max = $args->{results} || 10;
    require SOAP::Lite;
    require File::Basename;
    ## Look for GoogleSearch.wsdl in the lib/MT directory.
    my $dir = $INC{'MT.pm'};
    $dir = File::Basename::dirname($dir);
    my $wsdl = File::Spec->catfile($dir, 'MT', 'GoogleSearch.wsdl');
    {
        ## Turn off warnings, because the following can cause a
        ## "subroutine redefined" warning.
        local $^W = 0;
        *SOAP::XMLSchema1999::Deserializer::as_boolean =
        *SOAP::XMLSchemaSOAP1_1::Deserializer::as_boolean =
        \&SOAP::XMLSchema2001::Deserializer::as_boolean;
    }
    my $result = SOAP::Lite->service('file:' . $wsdl)
                           ->doGoogleSearch($key, $query, 0, $max,
                             0, '', 0, '', 'latin1', 'latin1'
                             );
    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $res = '';
    for my $rec (@{ $result->{resultElements} }) {
        $ctx->stash('google_result', $rec);
        my $out = $builder->build($ctx, $tokens, $cond);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
    }
    $res;
}

sub _hdlr_google_search_result {
    my($ctx, $args) = @_;
    my $res = $ctx->stash('google_result')
        or return $ctx->error(MT->translate(
           "You used an [_1] tag outside of the proper context.",
           '<$MTGoogleSearchResult$>' ));
    my $prop = $args->{property} || 'title';
    exists $res->{$prop}
        or return $ctx->error(MT->translate(
            'You used a non-existent property from the result structure.' ));
    $res->{$prop} || '';
}

sub _hdlr_pings {
    my($ctx, $args, $cond) = @_;
    require MT::Trackback;
    require MT::TBPing;
    my($tb, $cat);
    if (my $e = $ctx->stash('entry')) {
        $tb = MT::Trackback->load({ entry_id => $e->id });
        return '' unless $tb;
    } elsif ($cat = $ctx->stash('archive_category')) {
        $tb = MT::Trackback->load({ category_id => $cat->id });
        return '' unless $tb;
    } elsif (my $cat_name = $args->{category}) {
        require MT::Category;
        $cat = MT::Category->load({ label => $cat_name,
                                    blog_id => $ctx->stash('blog_id') })
            or return $ctx->error("No such category '$cat_name'");
        $tb = MT::Trackback->load({ category_id => $cat->id });
        return '' unless $tb;
    }
    my $res = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $sort_order = $args->{sort_order} || 'ascend';
    my %terms;
    $terms{tb_id} = $tb->id if $tb;
    $terms{blog_id} = $ctx->stash('blog_id');
    my %arg = ('sort' => 'created_on', direction => $sort_order);
    if (my $limit = $args->{lastn}) {
        $arg{direction} = 'descend';
        $arg{limit} = $limit;
    }
    my $iter = MT::TBPing->load_iter(\%terms, \%arg);
    while (my $ping = $iter->()) {
        $ctx->stash('ping' => $ping);
        local $ctx->{current_timestamp} = $ping->created_on;
        my $out = $builder->build($ctx, $tokens, $cond);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
    }
    $res;
}
sub _hdlr_pings_sent {
    my($ctx, $args, $cond) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTPingsSent');
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $res = '';
    my $pings = $e->pinged_url_list;
    for my $url (@$pings) {
        $ctx->stash('ping_sent_url', $url);
        defined(my $out = $builder->build($ctx, $tokens, $cond))
            or return $ctx->error($builder->errstr);
        $res .= $out;
    }
    $res;
}
sub _hdlr_pings_sent_url { $_[0]->stash('ping_sent_url') }
sub _no_ping_error {
    return $_[0]->error("You used an '$_[1]' tag outside of the context of " .
                        "a ping; perhaps you mistakenly placed it outside " .
                        "of an 'MTPings' container?");
}
sub _hdlr_ping_id {
    my $ping = $_[0]->stash('ping')
        or return $_[0]->_no_ping_error('MTPingID');
    $ping->id;
}
sub _hdlr_ping_title {
    sanitize_on($_[1]);
    my $ping = $_[0]->stash('ping')
        or return $_[0]->_no_ping_error('MTPingTitle');
    defined $ping->title ? $ping->title : '';
}
sub _hdlr_ping_url {
    sanitize_on($_[1]);
    my $ping = $_[0]->stash('ping')
        or return $_[0]->_no_ping_error('MTPingURL');
    defined $ping->source_url ? $ping->source_url : '';
}
sub _hdlr_ping_excerpt {
    sanitize_on($_[1]);
    my $ping = $_[0]->stash('ping')
        or return $_[0]->_no_ping_error('MTPingExcerpt');
    defined $ping->excerpt ? $ping->excerpt : '';
}
sub _hdlr_ping_ip {
    my $ping = $_[0]->stash('ping')
        or return $_[0]->_no_ping_error('MTPingIP');
    defined $ping->ip ? $ping->ip : '';
}
sub _hdlr_ping_blog_name {
    sanitize_on($_[1]);
    my $ping = $_[0]->stash('ping')
        or return $_[0]->_no_ping_error('MTPingBlogName');
    defined $ping->blog_name ? $ping->blog_name : '';
}

1;
__END__

=head1 NAME

MT::Template::Context - Movable Type Template Handlers

=head1 SYNOPSIS

    use MT::Template::Context;
    MT::Template::Context->add_tag( FooBar => sub {
        my($ctx, $args) = @_;
        my $foo = $ctx->stash('foo')
            or return $ctx->error("No foo in context");
        $foo->bar;
    } );

    ## In a template:
    ## <$MTFooBar$>

=head1 DESCRIPTION

I<MT::Template::Context> provides the implementation for all of the built-in
template tags in Movable Type, as well as the public interface to the
system's plugin interface.

This document focuses only on the public methods needed to implement plugins
in Movable Type, and the methods that plugin developers might wish to make
use of. Of course, plugins can make use of other objects loaded from the
Movable Type database, in which case you may wish to look at the documentation
for the classes in question (for example, I<MT::Entry>).

=head1 USAGE

=head2 MT::Template::Context->add_tag($name, \&subroutine)

I<add_tag> registers a simple "variable tag" with the system. An example of
such a tag might be C<E<lt>$MTEntryTitle$E<gt>>.

I<$name> is the name of the tag, without the I<MT> prefix, and
I<\&subroutine> a reference to a subroutine (either anonymous or named).
I<\&subroutine> should return either an error (see L<ERROR HANDLING>) or
a defined scalar value (returning C<undef> will be treated as an error, so
instead of returning C<undef>, always return the empty string instead).

For example:

    MT::Template::Context->add_tag(ServerUptime => sub { `uptime` });

This tag would be used in a template as C<E<lt>$MTServerUptime$E<gt>>.

The subroutine reference will be passed two arguments: the
I<MT::Template::Context> object with which the template is being built, and
a reference to a hash containing the arguments passed in through the template
tag. For example, if a tag C<E<lt>$MTFooBar$E<gt>> were called like

    <$MTFooBar baz="1" quux="2"$>

the second argument to the subroutine registered with this tag would be

    {
        'quux' => 2,
        'bar' => 1
    };

=head2 MT::Template::Context->add_container_tag($name, \&subroutine)

Registers a "container tag" with the template system. Container tags are
generally used to represent either a loop or a conditional. In practice, you
should probably use I<add_container_tag> just for loops--use
I<add_conditional_tag> for a conditional, because it will take care of much
of the backend work for you (most conditional tag handlers have a similar
structure).

I<$name> is the name of the tag, without the I<MT> prefix, and
I<\&subroutine> a reference to a subroutine (either anonymous or named).
I<\&subroutine> should return either an error (see L<ERROR HANDLING>) or
a defined scalar value (returning C<undef> will be treated as an error, so
instead of returning C<undef>, always return the empty string instead).

The subroutine reference will be passed two arguments: the
I<MT::Template::Context> object with which the template is being built, and
a reference to a hash containing the arguments passed in through the template
tag.

Since a container tag generally represents a loop, inside of your subroutine
you will need to use a loop construct to loop over some list of items, and
build the template tags used inside of the container for each of those
items. These inner template tags have B<already been compiled into a list of
tokens>. You need only use the I<MT::Builder> object to build this list of
tokens into a scalar string, then add the string to your output value. The
list of tokens is in C<$ctx-E<gt>stash('tokens')>, and the I<MT::Builder>
object is in C<$ctx-E<gt>stash('builder')>.

For example, if a tag C<E<lt>MTLoopE<gt>> were used like this:

    <MTLoop>
    The value of I is: <$MTLoopIValue$>
    </MTLoop>

a sample implementation of this set of tags might look like this:

    MT::Template::Context->add_container_tag(Loop => sub {
        my $ctx = shift;
        my $res = '';
        my $builder = $ctx->stash('builder');
        my $tokens = $ctx->stash('tokens');
        for my $i (1..5) {
            $ctx->stash('i_value', $i);
            defined(my $out = $builder->build($ctx, $tokens))
                or return $ctx->error($builder->errstr);
            $res .= $out;
        }
        $res;
    });

    MT::Template::Context->add_tag(LoopIValue => sub {
        my $ctx = shift;
        $ctx->stash('i_value');
    });

C<E<lt>$MTLoopIValue$E<gt>> is a simple variable tag. C<E<lt>MTLoopE<gt>> is
registered as a container tag, and it loops over the numbers 1 through 5,
building the list of tokens between C<E<lt>MTLoopE<gt>> and
C<E<lt>/MTLoopE<gt>> for each number. It checks for an error return value
from the C<$builder-E<gt>build> invocation each time through.

Use of the tags above would produce:

    The value of I is: 1
    The value of I is: 2
    The value of I is: 3
    The value of I is: 4
    The value of I is: 5

=head2 MT::Template::Context->add_conditional_tag($name, $condition)

Registers a conditional tag with the template system.

Conditional tags are technically just container tags, but in order to make
it very easy to write conditional tags, you can use the I<add_conditional_tag>
method. I<$name> is the name of the tag, without the I<MT> prefix, and
I<$condition> is a reference to a subroutine which should return true if
the condition is true, and false otherwise. If the condition is true, the
block of tags and markup inside of the conditional tag will be executed and
displayed; otherwise, it will be ignored.

For example, the following code registers two conditional tags:

    MT::Template::Context->add_conditional_tag(IfYes => sub { 1 });
    MT::Template::Context->add_conditional_tag(IfNo => sub { 0 });

C<E<lt>MTIfYesE<gt>> will always display its contents, because it always
returns 1; C<E<lt>MTIfNoE<gt>> will never display is contents, because it
always returns 0. So if these tags were to be used like this:

    <MTIfYes>Yes, this appears.</MTIfYes>
    <MTIfNo>No, this doesn't appear.</MTIfNo>

Only "Yes, this appears." would be displayed.

A more interesting example is to add a tag C<E<lt>MTEntryIfTitleE<gt>>,
to be used in entry context, and which will display its contents if the
entry has a title.

    MT::Template::Context->add_conditional_tag(EntryIfTitle => sub {
        my $e = $_[0]->stash('entry') or return;
        defined($e->title) && $e->title ne '';
    });

To be used like this:

    <MTEntries>
    <MTEntryIfTitle>
    This entry has a title: <$MTEntryTitle$>
    </MTEntryIfTitle>
    </MTEntries>

=head2 MT::Template::Context->add_global_filter($name, \&subroutine)

Registers a global tag attribute. More information is available in the
Movable Type manual, in the Template Tags section, in "Global Tag Attributes".

Global tag attributes can be used in any tag, and are essentially global
filters, used to filter the normal output of the tag and modify it in some
way. For example, the I<lower_case> global tag attribute can be used like
this:

    <$MTEntryTitle lower_case="1"$>

and will transform all entry titles to lower-case.

Using I<add_global_filter> you can add your own global filters. I<$name>
is the name of the filter (this should be lower-case for consistency), and
I<\&subroutine> is a reference to a subroutine that will be called to
transform the normal output of the tag. I<\&subroutine> will be given three
arguments: the standard scalar output of the tag, the value of the attribute
(C<1> in the above I<lower_case> example), and the I<MT::Template::Context>
object being used to build the template.

For example, the following adds a I<rot13> filter:

    MT::Template::Context->add_global_filter(rot13 => sub {
        (my $s = shift) =~ tr/a-zA-Z/n-za-mN-ZA-M/;
        $s;
    });

Which can be used like this:

    <$MTEntryTitle rot13="1"$>

Another example: if we wished to implement the built-in I<trim_to> filter
using I<add_global_filter>, we would use this:

    MT::Template::Context->add_global_filter(trim_to => sub {
        my($str, $len, $ctx) = @_;
        $str = substr $str, 0, $len if $len < length($str);
        $str;
    });

The second argument (I<$len>) is used here to determine the length to which
the string (I<$str>) should be trimmed.

Note: If you add multiple global filters, the order in which they are called
is undefined, so you should not rely on any particular ordering.

=head2 $ctx->stash($key [, $value ])

A simple data stash that can be used to store data between calls to different
tags in your plugin. For example, this is very useful when implementing a
container tag, as we saw above in the implementation of C<E<lt>MTLoopE<gt>>.

I<$key> should be a scalar string identifying the data that you are stashing.
I<$value>, if provided>, should be any scalar value (a string, a number, a
reference, an object, etc).

When called with only I<$key>, returns the stashed value for I<$key>; when
called with both I<$key> and I<$value>, sets the stash for I<$key> to
I<$value>.

=head1 ERROR HANDLING

If an error occurs in one of the subroutine handlers within your plugin,
you should return an error by calling the I<error> method on the I<$ctx>
object:

    return $ctx->error("the error message");

In particular, you might wish to use this if your tag expects to be called
in a particular context. For example, the C<E<lt>$MTEntry*$E<gt>> tags all
expect that when they are called, an entry will be in context. So they all
use

    my $entry = $ctx->stash('entry')
        or return $ctx->error("Tag called without an entry in context");

to ensure this.

=head1 AUTHOR & COPYRIGHT

Please see the I<MT> manpage for author, copyright, and license information.

=cut
