# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Blog.pm,v 1.40 2003/02/12 00:15:03 btrott Exp $

package MT::Blog;
use strict;

use MT::FileMgr;
use MT::Util;

use MT::Object;
@MT::Blog::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'name', 'description',
        'archive_path', 'archive_url', 'archive_type',
        'archive_type_preferred',
        'site_path', 'site_url',
        'days_on_index', 'file_extension',
        'email_new_comments', 'allow_comment_html',
        'autolink_urls', 'sort_order_posts', 'sort_order_comments',
        'allow_comments_default', 'server_offset', 'convert_paras',
        'convert_paras_comments', 'allow_pings_default',
        'status_default', 'allow_anon_comments', 'words_in_excerpt',
        'ping_weblogs', 'mt_update_key', 'language', 'welcome_msg',
        'google_api_key', 'email_new_pings', 'ping_blogs', 'ping_others',
        'autodiscover_links', 'sanitize_spec', 'cc_license',
        'is_dynamic',
## Have to keep these around for use in mt-upgrade.cgi.
        'archive_tmpl_daily', 'archive_tmpl_weekly', 'archive_tmpl_monthly',
        'archive_tmpl_category', 'archive_tmpl_individual',
    ],
    indexes => {
        name => 1,
    },
    datasource => 'blog',
    primary_key => 'id',
});

sub site_url {
    my $blog = shift;
    if (!@_ && $blog->is_dynamic) {
        my $cfg = MT::ConfigMgr->instance;
        my $path = $cfg->CGIPath;
        $path .= '/' unless $path =~ m!/$!;
        return $path . $cfg->ViewScript . '/' . $blog->id;
    } else {
        return $blog->SUPER::site_url(@_);
    }
}

sub archive_url {
    my $blog = shift;
    if (!@_ && $blog->is_dynamic) {
        return $blog->site_url;   ## site_url and archive_url are the same.
    } else {
        return $blog->SUPER::archive_url(@_);
    }
}

sub comment_text_filters {
    my $blog = shift;
    my $filters = $blog->convert_paras_comments;
    return [] unless $filters;
    if ($filters eq '1') {
        return [ '__default__' ];
    } else {
        return [ split /\s*,\s*/, $filters ];
    }
}

sub cc_license_url {
    my $cc = $_[0]->cc_license or return '';
    MT::Util::cc_url($cc);
}

use MT::Request;
sub load {
    my($class, $terms, $args) = @_;
    if (!wantarray) {
        my $blogs = MT::Request->instance->cache('blogs');
        unless ($blogs) {
            MT::Request->instance->cache('blogs', $blogs = {});
        }
        $terms = {} unless defined $terms;
        return $blogs->{$terms} if !ref($terms) && $blogs->{$terms};
        my $blog = $class->SUPER::load($terms, $args);
        return $blog ? ($blogs->{$blog->id} = $blog) : undef;
    } else {
        return $class->SUPER::load($terms, $args);
    }
}

sub file_mgr {
    my $blog = shift;
    unless (exists $blog->{__file_mgr}) {
## xxx need to add remote_host, remote_user, remote_pwd fields
## then pull params from there; if remote_host is defined, we
## assume we are using FTP?
        $blog->{__file_mgr} = MT::FileMgr->new('Local');
    }
    $blog->{__file_mgr};
}

sub remove {
    my $blog = shift;
    my @classes = qw( MT::Permission MT::Entry MT::Template
                      MT::Category MT::Notification );
    my $blog_id = $blog->id;
    for my $class (@classes) {
        eval "use $class;";
        ## We need to loop twice over the objects: first gather, then
        ## remove, so as not to throw our gathering out of whack by removing
        ## while we gather. :)
        my $iter = $class->load_iter({ blog_id => $blog_id });
        my @ids;
        while (my $obj = $iter->()) {
            push @ids, $obj->id;
        }
        ## The iterator is finished, so we can safely remove.
        for my $id (@ids) {
            my $obj = $class->load($id);
            $obj->remove;
        }
    }
    $blog->SUPER::remove;
}

1;
__END__

=head1 NAME

MT::Blog - Movable Type blog record

=head1 SYNOPSIS

    use MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    $blog->name('Some new name');
    $blog->save
        or die $blog->errstr;

=head1 DESCRIPTION

An I<MT::Blog> object represents a blog in the Movable Type system. It
contains all of the settings, preferences, and configuration for a particular
blog. It does not contain any per-author permissions settings--for those,
look at the I<MT::Permission> object.

=head1 USAGE

As a subclass of I<MT::Object>, I<MT::Blog> inherits all of the
data-management and -storage methods from that class; thus you should look
at the I<MT::Object> documentation for details about creating a new object,
loading an existing object, saving an object, etc.

The following methods are unique to the I<MT::Blog> interface:

=head2 $blog->file_mgr

Returns the I<MT::FileMgr> object specific to this particular blog.

=head1 DATA ACCESS METHODS

The I<MT::Blog> object holds the following pieces of data. These fields can
be accessed and set using the standard data access methods described in the
I<MT::Object> documentation.

=over 4

=item * id

The numeric ID of the blog.

=item * name

The name of the blog.

=item * description

The blog description.

=item * site_path

The path to the directory containing the blog's output index templates.

=item * site_url

The URL corresponding to the I<site_path>.

=item * archive_path

The path to the directory where the blog's archives are stored.

=item * archive_url

The URL corresponding to the I<archive_path>.

=item * server_offset

A slight misnomer, this is actually the timezone that the B<user> has
selected; the value is the offset from GMT.

=item * archive_type

A comma-separated list of archive types used in this particular blog, where
an archive type is one of the following: C<Individual>, C<Daily>, C<Weekly>,
C<Monthly>, or C<Category>. For example, a blog's I<archive_type> would be
C<Individual,Monthly> if the blog were using C<Individual> and C<Monthly>
archives.

=item * archive_type_preferred

The "preferred" archive type, which is used when constructing a link to the
archive page for a particular archive--if multiple archive types are selected,
for example, the link can only point to one of those archives. The preferred
archive type (which should be one of the archive types set in I<archive_type>,
above) specifies to which archive this link should point (among other things).

=item * days_on_index

The number of days to be displayed on the index.

=item * file_extension

The file extension to be used for archive pages.

=item * email_new_comments

A boolean flag specifying whether authors should be notified of new comments
posted on entries they have written.

=item * allow_comment_html

A boolean flag specifying whether HTML should be allowed in comments. If it
is not allowed, it is automatically stripped before building the page (note
that the content stored in the database is B<not> stripped).

=item * autolink_urls

A boolean flag specifying whether URLs in comments should be turned into
links. Note that this setting is only taken into account if
I<allow_comment_html> is turned off.

=item * sort_order_posts

The default sort order for entries. Valid values are either C<ascend> or
C<descend>.

=item * sort_order_comments

The default sort order for comments. Valid values are either C<ascend> or
C<descend>.

=item * allow_comments_default

The default value for the I<allow_comments> field in the I<MT::Entry> object.

=item * convert_paras

A boolean flag specifying whether paragraphs and line breaks should be
converted in entries.

=item * convert_paras_comments

A boolean flag specifying whether paragraphs and line breaks should be
converted in comments.

=item * status_default

The default value for the I<status> field in the I<MT::Entry> object.

=item * allow_anon_comments

A boolean flag specifying whether anonymous comments (those posted without
a name or an email address) are allowed.

=item * words_in_excerpt

The number of words in an auto-generated excerpt.

=item * ping_weblogs

A boolean flag specifying whether the system should send an XML-RPC ping to
I<weblogs.com> after an entry is saved.

=item * mt_update_key

The Movable Type Recently Updated Key to be sent to I<movabletype.org> after
an entry is saved.

=item * language

The language for date and time display for this particular blog.

=item * welcome_msg

The welcome message to be displayed on the main Editing Menu for this blog.
Should contain all desired HTML formatting.

=back

=head1 DATA LOOKUP

In addition to numeric ID lookup, you can look up or sort records by any
combination of the following fields. See the I<load> documentation in
I<MT::Object> for more information.

=over 4

=item * name

=back

=head1 NOTES

=over 4

=item *

When you remove a blog using I<MT::Blog::remove>, in addition to removing the
blog record, all of the entries, notifications, permissions, comments,
templates, and categories in that blog will also be removed.

=item *

Because the system needs to load I<MT::Blog> objects from disk relatively
often during the duration of one request, I<MT::Blog> objects are cached by
the I<MT::Blog::load> object so that each blog only need be loaded once. The
I<MT::Blog> objects are cached in the I<MT::Request> singleton object; note
that this caching B<only occurs> if the blogs are loaded by numeric ID.

=back

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
