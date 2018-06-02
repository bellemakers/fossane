# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: XMLRPCServer.pm,v 1.19 2003/03/07 06:51:51 btrott Exp $

package MT::XMLRPCServer;
use strict;

use MT;
use MT::Util qw( first_n_words decode_html );

use MT::ErrorHandler;
BEGIN { @MT::XMLRPCServer::ISA = qw( MT::ErrorHandler ) }

use vars qw( $MT_DIR );

my($HAVE_XML_PARSER);
BEGIN {
    eval { require XML::Parser };
    $HAVE_XML_PARSER = $@ ? 0 : 1;
}

sub _fault {
    SOAP::Fault->faultcode(1)->faultstring($_[0]);
}

sub mt_new {
    my $cfg = $ENV{MOD_PERL} ?
        Apache->request->dir_config('MTConfig') :
        $MT_DIR . '/mt.cfg';
    my $mt = MT->new( Config => $cfg )
        or die _fault(MT->errstr);
    $mt;
}

## This is sort of a hack. XML::Parser automatically makes everything
## UTF-8, and that is causing severe problems with the serialization
## of database records (what happens is this: we construct a string
## consisting of pack('N', length($string)) . $string. If the $string SV
## is flagged as UTF-8, the packed length is then upgraded to UTF-8,
## which turns characters with values greater than 128 into two bytes,
## like v194.129. And so on. This is obviously now what we want, because
## pack produces a series of bytes, not a string that should be mucked
## about with.)
##
## The following subroutine strips the UTF8 flag from a string, thus
## forcing it into a series of bytes. "pack 'C0'" is a magic way of
## forcing the following string to be packed as bytes, not as UTF8.

sub no_utf8 {
    for (@_) {
        next if ref;
        $_ = pack 'C0A*', $_;
    }
}

sub _login {
    my $class = shift;
    my($user, $pass, $blog_id) = @_;
    require MT::Author;
    my $author = MT::Author->load({ name => $user }) or return;
    $author->is_valid_password($pass) or return;
    return $author unless $blog_id;
    require MT::Permission;
    my $perms = MT::Permission->load({ author_id => $author->id,
                                       blog_id => $blog_id });
    ($author, $perms);
}

sub _publish {
    my $class = shift;
    my($mt, $entry, $no_ping) = @_;
    require MT::Blog;
    my $blog = MT::Blog->load($entry->blog_id);
    $mt->rebuild_entry( Entry => $entry, Blog => $blog,
                        BuildDependencies => 1 )
        or return $class->error("Rebuild error: " . $mt->errstr);
    unless ($no_ping) {
        $mt->ping_and_save(Blog => $blog, Entry => $entry)
            or return $class->error("Ping error: " . $mt->errstr);
    }
    1;
}

sub newPost {
    my $class = shift;
    my($appkey, $blog_id, $user, $pass, $item, $publish);
    if ($class eq 'blogger') {
        ($appkey, $blog_id, $user, $pass, my($content), $publish) = @_;
        $item->{description} = $content;
    } else {
        ($blog_id, $user, $pass, $item, $publish) = @_;
    }
    die _fault("No blog_id") unless $blog_id;
    no_utf8($blog_id, values %$item);
    unless ($HAVE_XML_PARSER) {
        for my $f (qw( title description mt_text_more
                       mt_excerpt mt_keywords )) {
            next unless defined $item->{$f}; 
            $item->{$f} = decode_html($item->{$f});
            $item->{$f} =~ s!&apos;!'!g;
        }
    }
    my $mt = mt_new();   ## Will die if MT->new fails.
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id)
        or die _fault("Invalid blog ID '$blog_id'");
    my($author, $perms) = __PACKAGE__->_login($user, $pass, $blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("No posting privileges") unless $perms && $perms->can_post;
    require MT::Entry;
    my $entry = MT::Entry->new;
    $entry->blog_id($blog_id);
    $entry->author_id($author->id);

    ## In 2.1 we changed the behavior of the $publish flag. Previously,
    ## it was used to determine the post status. That was a bad idea.
    ## So now entries added through XML-RPC are always set to publish,
    ## *unless* the user has set "NoPublishMeansDraft 1" in mt.cfg, which
    ## enables the old behavior.
    if ($mt->{cfg}->NoPublishMeansDraft) {
        $entry->status($publish ? MT::Entry::RELEASE() : MT::Entry::HOLD());
    } else {
        $entry->status(MT::Entry::RELEASE());
    }
    $entry->allow_comments($blog->allow_comments_default);
    $entry->allow_pings($blog->allow_pings_default);
    $entry->convert_breaks(defined $item->{mt_convert_breaks} ? $item->{mt_convert_breaks} : $blog->convert_paras);
    $entry->allow_comments($item->{mt_allow_comments})
        if exists $item->{mt_allow_comments};
    $entry->title($item->{title} || first_n_words($item->{description}, 5));
    $entry->text($item->{description});
    for my $field (qw( allow_pings )) {
        my $val = $item->{"mt_$field"};
        next unless defined $val;
        die _fault("Value for 'mt_$field' must be either 0 or 1 (was '$val')")
            unless $val == 0 || $val == 1;
        $entry->$field($val);
    }
    $entry->excerpt($item->{mt_excerpt}) if $item->{mt_excerpt};
    $entry->text_more($item->{mt_text_more}) if $item->{mt_text_more};
    $entry->keywords($item->{mt_keywords}) if $item->{mt_keywords};
    if (my $urls = $item->{mt_tb_ping_urls}) {
        $entry->to_ping_urls(join "\n", @$urls);
    }
    if (my $ts = $item->{dateCreated}) {
        my($y, $mo, $d, $h, $m, $s) = $ts =~
            /(\d{4})(\d{2})(\d{2})T(\d{2}):(\d{2}):(\d{2})/
            or die _fault("Invalid timestamp format");
        $entry->created_on(sprintf "%04d%02d%02d%02d%02d%02d",
            $y, $mo, $d, $h, $m, $s);
    }
    $entry->save;
    if ($publish) {
        __PACKAGE__->_publish($mt, $entry) or die _fault(__PACKAGE__->errstr);
    }
    SOAP::Data->type(string => $entry->id);
}

sub editPost {
    my $class = shift;
    my($appkey, $entry_id, $user, $pass, $item, $publish);
    if ($class eq 'blogger') {
        ($appkey, $entry_id, $user, $pass, my($content), $publish) = @_;
        $item->{description} = $content;
    } else {
        ($entry_id, $user, $pass, $item, $publish) = @_;
    }
    die _fault("No entry_id") unless $entry_id;
    no_utf8(values %$item);
    unless ($HAVE_XML_PARSER) {
        for my $f (qw( title description mt_text_more
                       mt_excerpt mt_keywords )) {
            next unless defined $item->{$f}; 
            $item->{$f} = decode_html($item->{$f});
            $item->{$f} =~ s!&apos;!'!g;
        }
    }
    my $mt = mt_new();   ## Will die if MT->new fails.
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id)
        or die _fault("Invalid entry ID '$entry_id'");
    my($author, $perms) = __PACKAGE__->_login($user, $pass, $entry->blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("Not privileged to edit entry")
        unless $perms && $perms->can_edit_entry($entry, $author);
    $entry->status(MT::Entry::RELEASE()) if $publish;
    $entry->title($item->{title}) if $item->{title};
    $entry->text($item->{description});
    $entry->convert_breaks($item->{mt_convert_breaks})
        if exists $item->{mt_convert_breaks};
    $entry->allow_comments($item->{mt_allow_comments})
        if exists $item->{mt_allow_comments};
    for my $field (qw( allow_pings )) {
        my $val = $item->{"mt_$field"};
        next unless defined $val;
        die _fault("Value for 'mt_$field' must be either 0 or 1 (was '$val')")
            unless $val == 0 || $val == 1;
        $entry->$field($val);
    }
    $entry->excerpt($item->{mt_excerpt}) if defined $item->{mt_excerpt};
    $entry->text_more($item->{mt_text_more}) if defined $item->{mt_text_more};
    $entry->keywords($item->{mt_keywords}) if defined $item->{mt_keywords};
    if (my $urls = $item->{mt_tb_ping_urls}) {
        $entry->to_ping_urls(join "\n", @$urls);
    }
    if (my $ts = $item->{dateCreated}) {
        my($y, $mo, $d, $h, $m, $s) = $ts =~
            /(\d{4})(\d{2})(\d{2})T(\d{2}):(\d{2}):(\d{2})/
            or die _fault("Invalid timestamp format");
        $entry->created_on(sprintf "%04d%02d%02d%02d%02d%02d",
            $y, $mo, $d, $h, $m, $s);
    }
    $entry->save;
    if ($publish) {
        __PACKAGE__->_publish($mt, $entry) or die _fault(__PACKAGE__->errstr);
    }
    SOAP::Data->type(boolean => 1);
}

sub getUsersBlogs {
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
    my($appkey, $user, $pass) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    my($author) = __PACKAGE__->_login($user, $pass);
    die _fault("Invalid login") unless $author;
    require MT::Permission;
    require MT::Blog;
    my $iter = MT::Permission->load_iter({ author_id => $author->id });
    my @res;
    while (my $perms = $iter->()) {
        next unless $perms->can_post;
        my $blog = MT::Blog->load($perms->blog_id);
        push @res, { url => SOAP::Data->type(string => $blog->site_url),
                     blogid => SOAP::Data->type(string => $blog->id),
                     blogName => SOAP::Data->type(string => $blog->name) };
    }
    \@res;
}

sub getUserInfo {
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
    my($appkey, $user, $pass) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    my($author) = __PACKAGE__->_login($user, $pass);
    die _fault("Invalid login") unless $author;
    my($fname, $lname) = split /\s+/, $author->name;
    $lname ||= '';
    { userid => SOAP::Data->type(string => $author->id),
      firstname => SOAP::Data->type(string => $fname),
      lastname => SOAP::Data->type(string => $lname),
      nickname => SOAP::Data->type(string => $author->nickname),
      email => SOAP::Data->type(string => $author->email),
      url => SOAP::Data->type(string => $author->url) };
}

sub getRecentPosts {
    my $class = shift;
    my($blog_id, $user, $pass, $num, $titles_only);
    if ($class eq 'blogger') {
        (my($appkey), $blog_id, $user, $pass, $num, $titles_only) = @_;
    } else {
        ($blog_id, $user, $pass, $num, $titles_only) = @_;
    }
    my $mt = mt_new();   ## Will die if MT->new fails.
    my($author, $perms) = __PACKAGE__->_login($user, $pass, $blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("No posting privileges") unless $perms && $perms->can_post;
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    require MT::Entry;
    my $iter = MT::Entry->load_iter({ blog_id => $blog_id },
        { 'sort' => 'created_on',
          direction => 'descend',
          limit => $num });
    my @res;
    while (my $entry = $iter->()) {
        my $co = sprintf "%04d%02d%02dT%02d:%02d:%02d",
            unpack 'A4A2A2A2A2A2', $entry->created_on;
        my $row = { dateCreated => SOAP::Data->type(dateTime => $co),
                    userid => SOAP::Data->type(string => $entry->author_id),
                    postid => SOAP::Data->type(string => $entry->id), };
        if ($class eq 'blogger') {
            $row->{content} = SOAP::Data->type(string => $entry->text);
        } else {
            $row->{title} = SOAP::Data->type(string => $entry->title);
            unless ($titles_only) {
                $row->{description} = SOAP::Data->type(string => $entry->text);
                my $link = $entry->permalink;
                $row->{link} = SOAP::Data->type(string => $link);
                $row->{permaLink} = SOAP::Data->type(string => $link),
                $row->{mt_allow_comments} = SOAP::Data->type(int => $entry->allow_comments);
                $row->{mt_allow_pings} = SOAP::Data->type(int => $entry->allow_pings);
                $row->{mt_convert_breaks} = SOAP::Data->type(string => $entry->convert_breaks);
                $row->{mt_text_more} = SOAP::Data->type(string => $entry->text_more);
                $row->{mt_excerpt} = SOAP::Data->type(string => $entry->excerpt);
                $row->{mt_keywords} = SOAP::Data->type(string => $entry->keywords);
            }
        }
        push @res, $row;
    }
    \@res;
}

sub getRecentPostTitles {
    getRecentPosts(@_, 1);
}

sub deletePost {
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
    my($appkey, $entry_id, $user, $pass, $publish) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id)
        or die _fault("Invalid entry ID '$entry_id'");
    my($author, $perms) = __PACKAGE__->_login($user, $pass, $entry->blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("Not privileged to delete entry")
        unless $perms && $perms->can_edit_entry($entry, $author);
    $entry->remove;
    if ($publish) {
        __PACKAGE__->_publish($mt, $entry, 1) or die _fault(__PACKAGE__->errstr);
    }
    SOAP::Data->type(boolean => 1);
}

sub getPost {
    my $class = shift;
    my($entry_id, $user, $pass) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id)
        or die _fault("Invalid entry ID '$entry_id'");
    my($author, $perms) = __PACKAGE__->_login($user, $pass, $entry->blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("Not privileged to get entry")
        unless $perms && $perms->can_edit_entry($entry, $author);
    my $co = sprintf "%04d%02d%02dT%02d:%02d:%02d",
        unpack 'A4A2A2A2A2A2', $entry->created_on;
    require MT::Blog;
    my $blog = MT::Blog->load($entry->blog_id);
    my $link = $entry->permalink;
    {
        dateCreated => SOAP::Data->type(dateTime => $co),
        userid => SOAP::Data->type(string => $entry->author_id),
        postid => SOAP::Data->type(string => $entry->id),
        description => SOAP::Data->type(string => $entry->text),
        title => SOAP::Data->type(string => $entry->title),
        link => SOAP::Data->type(string => $link),
        permaLink => SOAP::Data->type(string => $link),
        mt_allow_comments => SOAP::Data->type(int => $entry->allow_comments),
        mt_allow_pings => SOAP::Data->type(int => $entry->allow_pings),
        mt_convert_breaks => SOAP::Data->type(string => $entry->convert_breaks),
        mt_text_more => SOAP::Data->type(string => $entry->text_more),
        mt_excerpt => SOAP::Data->type(string => $entry->excerpt),
        mt_keywords => SOAP::Data->type(string => $entry->keywords),
    }
}

sub supportedMethods {
    [ 'blogger.newPost', 'blogger.editPost', 'blogger.getRecentPosts',
      'blogger.getUsersBlogs', 'blogger.getUserInfo', 'blogger.deletePost',
      'metaWeblog.getPost', 'metaWeblog.newPost', 'metaWeblog.editPost',
      'metaWeblog.getRecentPosts', 'metaWeblog.newMediaObject',
      'mt.getCategoryList', 'mt.setPostCategories', 'mt.getPostCategories',
      'mt.getTrackbackPings', 'mt.supportedTextFilters',
      'mt.getRecentPostTitles', 'mt.publishPost' ];
}

sub supportedTextFilters {
    my $mt = mt_new();   ## Will die if MT->new fails.
    my $filters = $mt->all_text_filters;
    my @res;
    for my $filter (keys %$filters) {
        push @res, {
            key => SOAP::Data->type(string => $filter),
            label => SOAP::Data->type(string => $filters->{$filter}{label})
        };
    }
    \@res;
}

## getCategoryList, getPostCategories, and setPostCategories were
## originally written by Daniel Drucker with the assistance of
## Six Apart, then later modified by Six Apart.

sub getCategoryList {
    my $class = shift;
    my($blog_id, $user, $pass) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    my($author, $perms) = $class->_login($user, $pass, $blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("Author does not have privileges")
        unless $perms && $perms->can_post;
    require MT::Category;
    my $iter = MT::Category->load_iter({ blog_id => $blog_id });
    my @data;
    while (my $cat = $iter->()) {
        push @data, {
            categoryName => SOAP::Data->type(string => $cat->label),
            categoryId => SOAP::Data->type(string => $cat->id)
        };
    }
    \@data;
}

sub getPostCategories {
    my $class = shift;
    my($entry_id, $user, $pass) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id)
        or die _fault("Invalid entry ID '$entry_id'");
    my($author, $perms) = $class->_login($user, $pass, $entry->blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("No posting privileges") unless $perms && $perms->can_post;
    my @data;
    my $prim = $entry->category;
    my $cats = $entry->categories;
    for my $cat (@$cats) {
        my $is_primary = $prim && $cat->id == $prim->id ? 1 : 0;
        push @data, {
            categoryName => SOAP::Data->type(string => $cat->label),
            categoryId => SOAP::Data->type(string => $cat->id),
            isPrimary => SOAP::Data->type(boolean => $is_primary),
        };
    }
    \@data;
}

sub setPostCategories {
    my $class = shift;
    my($entry_id, $user, $pass, $cats) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    require MT::Entry;
    require MT::Placement;
    my $entry = MT::Entry->load($entry_id)
         or die _fault("Invalid entry ID '$entry_id'");
    my($author, $perms) = $class->_login($user, $pass, $entry->blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("No posting privileges") unless $perms && $perms->can_post;
    my @place = MT::Placement->load({ entry_id => $entry_id });
    for my $place (@place) {
         $place->remove;
    }
    ## Keep track of which category is named the primary category.
    ## If the first structure in the array does not have an isPrimary
    ## key, we just make it the primary category; if it does, we use
    ## that flag to determine the primary category.
    my $is_primary = 1;
    for my $cat (@$cats) {
         my $place = MT::Placement->new;
         $place->entry_id($entry_id);
         $place->blog_id($entry->blog_id);
         if (defined $cat->{isPrimary} && $is_primary) {
             $place->is_primary($cat->{isPrimary});
         } else {
             $place->is_primary($is_primary);
         }
         ## If we just set the is_primary flag to 1, we don't want to
         ## make any other categories primary.
         $is_primary = 0 if $place->is_primary;
         $place->category_id($cat->{categoryId});
         $place->save
              or die _fault("Saving placement failed: " . $place->errstr);
    }
    SOAP::Data->type(boolean => 1);
}

sub getTrackbackPings {
    my $class = shift;
    my($entry_id) = @_;
    require MT::Trackback;
    require MT::TBPing;
    my $mt = mt_new();   ## Will die if MT->new fails.
    my $tb = MT::Trackback->load({ entry_id => $entry_id })
        or return [];
    my $iter = MT::TBPing->load_iter({ tb_id => $tb->id });
    my @data;
    while (my $ping = $iter->()) {
        push @data, {
            pingTitle => SOAP::Data->type(string => $ping->title),
            pingURL => SOAP::Data->type(string => $ping->source_url),
            pingIP => SOAP::Data->type(string => $ping->ip),
        };
    }
    \@data;
}

sub publishPost {
    my $class = shift;
    my($entry_id, $user, $pass) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id)
        or die _fault("Invalid entry ID '$entry_id'");
    my($author, $perms) = __PACKAGE__->_login($user, $pass, $entry->blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("Not privileged to edit entry")
        unless $perms && $perms->can_edit_entry($entry, $author);
    $mt->rebuild_entry( Entry => $entry, BuildDependencies => 1 )
        or die _fault("Publish failed: " . $mt->errstr);
    SOAP::Data->type(boolean => 1);
}

sub newMediaObject {
    my $class = shift;
    my($blog_id, $user, $pass, $file) = @_;
    my $mt = mt_new();   ## Will die if MT->new fails.
    my($author, $perms) = __PACKAGE__->_login($user, $pass, $blog_id);
    die _fault("Invalid login") unless $author;
    die _fault("Not privileged to upload files")
        unless $perms && $perms->can_upload;
    require MT::Blog;
    require File::Spec;
    my $blog = MT::Blog->load($blog_id);
    my $fname = $file->{name} or die _fault("No filename provided");
    if ($fname =~ m!\.\.|\0|\|!) {
        die _fault("Invalid filename '$fname'");
    }
    my $local_file = File::Spec->catfile($blog->site_path, $file->{name});
    my $fmgr = $blog->file_mgr;
    my($vol, $path, $name) = File::Spec->splitpath($local_file);
    $path =~ s!/$!!;  ## OS X doesn't like / at the end in mkdir().
    unless ($fmgr->exists($path)) {
        $fmgr->mkpath($path)
            or die _fault("Error making path '$path': " . $fmgr->errstr);
    }
    defined(my $bytes = $fmgr->put_data($file->{bits}, $local_file, 'upload'))
        or die _fault("Error writing uploaded file: " . $fmgr->errstr);
    my $url = $blog->site_url . $fname;
    { url => SOAP::Data->type(string => $url) };
}

## getTemplate and setTemplate are not applicable in MT's template
## structure, so they are unimplemented (they return a fault).
## We assign it twice to get rid of "setTemplate used only once" warnings.

sub getTemplate {
    die _fault(
        "Template methods are not implemented, due to differences between " .
        "the Blogger API and the Movable Type API.");
}
*setTemplate = *setTemplate = \&getTemplate;

## The above methods will be called as blogger.newPost, blogger.editPost,
## etc., because we are implementing Blogger's API. Thus, the empty
## subclass.
package blogger;
BEGIN { @blogger::ISA = qw( MT::XMLRPCServer ); }

package metaWeblog;
BEGIN { @metaWeblog::ISA = qw( MT::XMLRPCServer ); }

package mt;
BEGIN { @mt::ISA = qw( MT::XMLRPCServer ); }

1;
