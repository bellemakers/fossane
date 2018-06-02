# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Entry.pm,v 1.61 2003/05/28 21:15:52 btrott Exp $

package MT::Entry;
use strict;

use MT::Author;
use MT::Category;
use MT::Placement;
use MT::Comment;
use MT::Util qw( archive_file_for discover_tb );

use MT::Object;
@MT::Entry::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'blog_id', 'status', 'author_id', 'allow_comments',
        'title', 'excerpt', 'text', 'text_more', 'convert_breaks',
        'to_ping_urls', 'pinged_urls', 'allow_pings', 'keywords',
        'tangent_cache',
## Have to keep this around for use in mt-upgrade.cgi.
        'category_id',
    ],
    indexes => {
        blog_id => 1,
        status => 1,
        author_id => 1,
        created_on => 1,
        modified_on => 1,
    },
    audit => 1,
    datasource => 'entry',
    primary_key => 'id',
});

use constant HOLD    => 1;
use constant RELEASE => 2;
use constant REVIEW => 3;

use Exporter;
*import = \&Exporter::import;
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( HOLD RELEASE REVIEW );

sub status_text {
    my $s = $_[0];
    $s == HOLD ? "Draft" :
        $s == RELEASE ? "Publish" :
            $s == REVIEW ? "Review" : '';
}

sub status_int {
    my $s = lc $_[0];   ## Lower-case it so that it's case-insensitive
    $s eq 'draft' ? HOLD :
        $s eq 'publish' ? RELEASE :
            $s eq 'review' ? REVIEW : undef;
}

sub next {
    my $entry = shift;
    my($publish_only) = @_;
    unless ($entry->{__next}) {
        $entry->{__next} = MT::Entry->load(
            { blog_id => $entry->blog_id,
              $publish_only ? (status => RELEASE) : () },
            { limit => 1,
              'sort' => 'created_on',
              direction => 'ascend',
              start_val => $entry->created_on });
    }
    $entry->{__next};
}

sub previous {
    my $entry = shift;
    my($publish_only) = @_;
    unless ($entry->{__previous}) {
        $entry->{__previous} = MT::Entry->load(
            { blog_id => $entry->blog_id,
              $publish_only ? (status => RELEASE) : () },
            { limit => 1,
              'sort' => 'created_on',
              direction => 'descend',
              start_val => $entry->created_on });
    }
    $entry->{__previous};
}

sub author {
    my $entry = shift;
    unless ($entry->{__author}) {
        $entry->{__author} = MT::Author->load($entry->author_id);
    }
    $entry->{__author};
}

## To speed up <$MTEntryCategory$> (and category-loading in general),
## the first time either ->category or ->categories is used, we load the
## list of placements (entry-category mappings) into memory into an
## MT::Request object. Lookups to determine if an entry has a category are
## thus very fast. We add a new config setting NoPlacementCache in case
## this causes problems for anyone. :)

sub _placement_cache {
    my($blog_id) = @_;
    my $r = MT::Request->instance;
    my $cache = $r->cache('all_placements');
    unless ($cache->{$blog_id}) {
        $cache->{$blog_id} = {};
        $r->cache('all_placements', $cache);
        require MT::Placement;
        my @p = MT::Placement->load({ blog_id => $blog_id });
        for my $p (@p) {
            push @{ $cache->{$blog_id}{all}{$p->entry_id} }, $p->category_id;
            $cache->{$blog_id}{primary}{$p->entry_id} = $p->category_id
                if $p->is_primary;
        }
    }
    $cache->{$blog_id};
}

sub category {
    my $entry = shift;
    unless ($entry->{__category}) {
        unless (MT::ConfigMgr->instance->NoPlacementCache) {
            my $cache = _placement_cache($entry->blog_id);
            my $p = $cache->{primary}{$entry->id} or return;
            $entry->{__category} = MT::Category->load($p);
        } else {
            $entry->{__category} = MT::Category->load(undef,
                { 'join' => [ 'MT::Placement', 'category_id',
                            { entry_id => $entry->id,
                              is_primary => 1 } ] },
            );
        }
    }
    $entry->{__category};
}

sub categories {
    my $entry = shift;
    unless ($entry->{__categories}) {
        unless (MT::ConfigMgr->instance->NoPlacementCache) {
            my $cache = _placement_cache($entry->blog_id);
            my $p = $cache->{all}{$entry->id} or return;
            for my $place (@$p) {
                push @{ $entry->{__categories} },
                    MT::Category->load($place);
            }
        } else {
            $entry->{__categories} = [ MT::Category->load(undef,
                { 'join' => [ 'MT::Placement', 'category_id',
                            { entry_id => $entry->id } ] },
            ) ];
        }
        $entry->{__categories} = [ sort { $a->label cmp $b->label }
                                   @{ $entry->{__categories} } ];
    }
    $entry->{__categories};
}

sub is_in_category {
    my $entry = shift;
    my($cat) = @_;
    my $cats = $entry->categories;
    for my $c (@$cats) {
        return 1 if $c->id == $cat->id;
    }
    0;
}

sub comments {
    my $entry = shift;
    unless ($entry->{__comments}) {
        $entry->{__comments} = [ MT::Comment->load({
            entry_id => $entry->id
        }) ];
    }
    $entry->{__comments};
}

sub comment_count {
    my $entry = shift;
    unless ($entry->{__comment_count}) {
        $entry->{__comment_count} = MT::Comment->count({
            entry_id => $entry->id
        });
    }
    $entry->{__comment_count};
}

sub ping_count {
    my $entry = shift;
    unless ($entry->{__ping_count}) {
        require MT::Trackback;
        require MT::TBPing;
        my $tb = MT::Trackback->load({ entry_id => $entry->id });
        $entry->{__ping_count} = $tb ?
            MT::TBPing->count({ tb_id => $tb->id }) : 0;
    }
    $entry->{__ping_count};
}

sub archive_file {
    my $entry = shift;
    my($at) = @_;
    my $blog_id = $entry->blog_id;
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id) or
        return $entry->error(MT->translate(
            "Load of blog '[_1]' failed: [_2]", $blog_id, MT::Blog->errstr));
    unless ($at) {
        $at = $blog->archive_type_preferred || $blog->archive_type;
        return '' if !$at || $at eq 'None';
        my %at = map { $_ => 1 } split /,/, $at;
        for my $tat (qw( Individual Daily Weekly Monthly Category )) {
            $at = $tat if $at{$tat};
        }
    }
    archive_file_for($entry, $blog, $at);
}

sub archive_url {
    my $entry = shift;
    my $blog_id = $entry->blog_id;
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id) or
        return $entry->error(MT->translate(
            "Load of blog '[_1]' failed: [_2]", $blog_id, MT::Blog->errstr));
    my $url = $blog->archive_url;
    $url .= '/' unless $url =~ m!/$!;
    $url . $entry->archive_file(@_);
}

sub permalink {
    my $entry = shift;
    my $blog_id = $entry->blog_id;
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id) or
        return $entry->error(MT->translate(
            "Load of blog '[_1]' failed: [_2]", $blog_id, MT::Blog->errstr));
    my $url = $entry->archive_url(@_);
    $url .= '#' . sprintf("%06d", $entry->id)
        unless $blog->archive_type_preferred eq 'Individual';
    $url;
}

sub text_filters {
    my $entry = shift;
    my $filters = $entry->convert_breaks;
    if (!defined $filters) {
        require MT::Blog;
        my $blog = MT::Blog->load($entry->blog_id) or return [];
        $filters = $blog->convert_paras;
    }
    return [] unless $filters;
    if ($filters eq '1') {
        return [ '__default__' ];
    } else {
        return [ split /\s*,\s*/, $filters ];
    }
}

sub get_excerpt {
    my $entry = shift;
    my($words) = @_;
    return $entry->excerpt if $entry->excerpt;
    my $excerpt = MT->apply_text_filters($entry->text, $entry->text_filters);
    my $blog = MT::Blog->load($entry->blog_id);
    MT::Util::first_n_words($excerpt, $words || $blog->words_in_excerpt || 40) . '...';
}

*pinged_url_list = _mk_url_list_meth('pinged_urls');
*to_ping_url_list = _mk_url_list_meth('to_ping_urls');

sub _mk_url_list_meth {
    my($meth) = @_;
    sub {
        my $entry = shift;
        return [] unless $entry->$meth() && $entry->$meth() =~ /\S/;
        [ split /\r?\n/, $entry->$meth() ];
    }
}

sub save {
    my $entry = shift;

    ## If we need to auto-discover TrackBack ping URLs, do that here.
    require MT::Blog;
    my $blog = MT::Blog->load($entry->blog_id);
    if ($blog->autodiscover_links) {
        my $archive_url = $blog->archive_url;
        my %to_ping = map { $_ => 1 } @{ $entry->to_ping_url_list };
        my %pinged = map { $_ => 1 } @{ $entry->pinged_url_list };
        my $body = MT->apply_text_filters($entry->text, $entry->text_filters);
        while ($body =~ m!<a.*?href=(["']?)([^'">]+)\1!gsi) {
            my $url = $2;
            next if $url =~ /^$archive_url/;
            if (my $item = discover_tb($url)) {
                $to_ping{ $item->{ping_url} } = 1
                    unless $pinged{$item->{ping_url}};
            }
        }
        $entry->to_ping_urls(join "\n", keys %to_ping);
    }

    $entry->SUPER::save(@_) or return;

    ## If pings are allowed on this entry, create or update
    ## the corresponding TrackBack object for this entry.
    require MT::Trackback;
    if ($entry->allow_pings) {
        my $tb;
        unless ($tb = MT::Trackback->load({ entry_id => $entry->id })) {
            $tb = MT::Trackback->new;
            $tb->blog_id($entry->blog_id);
            $tb->entry_id($entry->id);
            $tb->category_id(0);   ## category_id can't be NULL
        }
        $tb->title($entry->title);
        require MT::Blog;
        my $blog = MT::Blog->load($entry->blog_id);
        $tb->description($entry->get_excerpt);
        $tb->url($entry->permalink);
        $tb->is_disabled(0);
        $tb->save
            or return $entry->error($tb->errstr);
    } else {
        ## If there is a TrackBack item for this entry, but
        ## pings are now disabled, make sure that we mark the
        ## object as disabled.
        if (my $tb = MT::Trackback->load({ entry_id => $entry->id })) {
            $tb->is_disabled(1);
            $tb->save
                or return $entry->error($tb->errstr);
        }
    }
    1;
}

sub remove {
    my $entry = shift;
    my $comments = $entry->comments;
    for my $comment (@$comments) {
        $comment->remove;
    }
    require MT::Placement;
    my @place = MT::Placement->load({ entry_id => $entry->id });
    for my $place (@place) {
        $place->remove;
    }
    require MT::Trackback;
    my @tb = MT::Trackback->load({ entry_id => $entry->id });
    for my $tb (@tb) {
        $tb->remove;
    }
    $entry->SUPER::remove;
}

1;
__END__

=head1 NAME

MT::Entry - Movable Type entry record

=head1 SYNOPSIS

    use MT::Entry;
    my $entry = MT::Entry->new;
    $entry->blog_id($blog->id);
    $entry->status(MT::Entry::RELEASE());
    $entry->author_id($author->id);
    $entry->title('My title');
    $entry->text('Some text');
    $entry->save
        or die $entry->errstr;

=head1 DESCRIPTION

An I<MT::Entry> object represents an entry in the Movable Type system. It
contains all of the metadata about the entry (author, status, category, etc.),
as well as the actual body (and extended body) of the entry.

=head1 USAGE

As a subclass of I<MT::Object>, I<MT::Entry> inherits all of the
data-management and -storage methods from that class; thus you should look
at the I<MT::Object> documentation for details about creating a new object,
loading an existing object, saving an object, etc.

The following methods are unique to the I<MT::Entry> interface:

=head2 $entry->next

Loads and returns the next entry, where "next" is defined as the next record
in ascending chronological order (the entry posted after the current entry).
entry I<$entry>).

Returns an I<MT::Entry> object representing this next entry; if there is not
a next entry, returns C<undef>.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->previous

Loads and returns the previous entry, where "previous" is defined as the
previous record in ascending chronological order (the entry posted before the
current entry I<$entry>).

Returns an I<MT::Entry> object representing this previous entry; if there is
not a next entry, returns C<undef>.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->author

Returns an I<MT::Author> object representing the author of the entry
I<$entry>. If the author record has been removed, returns C<undef>.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->category

Returns an I<MT::Category> object representing the primary category of the
entry I<$entry>. If a primary category has not been assigned, returns
C<undef>.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->categories

Returns a reference to an array of I<MT::Category> objects representing the
categories to which the entry I<$entry> has been assigned (both primary and
secondary categories). If the entry has not been assigned to any categories,
returns a reference to an empty array.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->is_in_category($cat)

Returns true if the entry I<$entry> has been assigned to entry I<$cat>, false
otherwise.

=head2 $entry->comments

Returns a reference to an array of I<MT::Comment> objects representing the
comments made on the entry I<$entry>. If no comments have been made on the
entry, returns a reference to an empty array.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->comment_count

Returns the number of comments made on this entry.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->ping_count

Returns the number of TrackBack pings made on this entry.

Caches the return value internally so that subsequent calls will not have to
re-query the database.

=head2 $entry->archive_file([ $archive_type ])

Returns the name of/path to the archive file for the entry I<$entry>. If
I<$archive_type> is not specified, and you are using multiple archive types
for your blog, the path is created from the preferred archive type that you
have selected. If I<$archive_type> is specified, it should be one of the
following values: C<Individual>, C<Daily>, C<Weekly>, C<Monthly>, and
C<Category>.

=head2 $entry->archive_url([ $archive_type ])

Returns the absolute URL to the archive page for the entry I<$entry>. This
calls I<archive_file> internally, so if I<$archive_type> is specified, it
is merely passed through to that method. In other words, this is the
blog Archive URL plus the results of I<archive_file>.

=head2 $entry->permalink([ $archive_type ])

Returns the (smart) permalink for the entry I<$entry>. Internally this calls
I<archive_url>, which calls I<archive_file>, so I<$archive_type> (if
specified) is merely passed through to that method. The result of this
method is the same as I<archive_url> plus the URI fragment
(C<#entry_id>), unless the preferred archive type is Individual, in which
case the two methods give exactly the same results.

=head2 $entry->text_filters

Returns a reference to an array of text filter keynames (the short names
that are the first argument to I<MT::add_text_filter>. This list can be
passed directly in as the second argument to I<MT::apply_text_filters>.

=head1 DATA ACCESS METHODS

The I<MT::Entry> object holds the following pieces of data. These fields can
be accessed and set using the standard data access methods described in the
I<MT::Object> documentation.

=over 4

=item * id

The numeric ID of the entry.

=item * blog_id

The numeric ID of the blog in which this entry has been posted.

=item * author_id

The numeric ID of the author who posted this entry.

=item * status

The status of the entry, either Publish (C<2>) or Draft (C<1>).

=item * allow_comments

A boolean flag specifying whether comments are allowed on this entry. This
setting determines whether C<E<lt>MTEntryIfAllowCommentsE<gt>> containers are
displayed for this entry.

=item * convert_breaks

A boolean flag specifying whether line and paragraph breaks should be converted
when rebuilding this entry.

=item * title

The title of the entry.

=item * excerpt

The excerpt of the entry.

=item * text

The main body text of the entry.

=item * text_more

The extended body text of the entry.

=item * created_on

The timestamp denoting when the entry record was created, in the format
C<YYYYMMDDHHMMSS>. Note that the timestamp has already been adjusted for the
selected timezone.

=item * modified_on

The timestamp denoting when the entry record was last modified, in the
format C<YYYYMMDDHHMMSS>. Note that the timestamp has already been adjusted
for the selected timezone.

=back

=head1 DATA LOOKUP

In addition to numeric ID lookup, you can look up or sort records by any
combination of the following fields. See the I<load> documentation in
I<MT::Object> for more information.

=over 4

=item * blog_id

=item * status

=item * author_id

=item * created_on

=item * modified_on

=back

=head1 NOTES

=over 4

=item *

When you remove an entry using I<MT::Entry::remove>, in addition to removing
the entry record, all of the comments and placements (I<MT::Comment> and
I<MT::Placement> records, respectively) for this entry will also be removed.

=back

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
