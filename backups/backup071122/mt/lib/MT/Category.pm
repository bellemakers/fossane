# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Category.pm,v 1.17 2003/02/12 00:15:03 btrott Exp $

package MT::Category;
use strict;

use MT::Object;
@MT::Category::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'blog_id', 'label', 'author_id', 'ping_urls', 'description',
        'allow_pings',
    ],
    indexes => {
        blog_id => 1,
        label => 1,
    },
    datasource => 'category',
    primary_key => 'id',
});

sub ping_url_list {
    my $cat = shift;
    return [] unless $cat->ping_urls && $cat->ping_urls =~ /\S/;
    [ split /\r?\n/, $cat->ping_urls ];
}

sub save {
    my $cat = shift;
    $cat->SUPER::save(@_) or return;

    ## If pings are allowed on this entry, create or update
    ## the corresponding Trackback object for this entry.
    require MT::Trackback;
    if ($cat->allow_pings) {
        my $tb;
        unless ($tb = MT::Trackback->load({
                                 category_id => $cat->id })) {
            $tb = MT::Trackback->new;
            $tb->blog_id($cat->blog_id);
            $tb->category_id($cat->id);
            $tb->entry_id(0);   ## entry_id can't be NULL
        }
        if (defined(my $pass = $cat->{__tb_passphrase})) {
            $tb->passphrase($pass);
        }
        $tb->title($cat->label);
        $tb->description($cat->description);
        require MT::Blog;
        my $blog = MT::Blog->load($cat->blog_id);
        my $url = $blog->archive_url;
        $url .= '/' unless $url =~ m!/$!;
        $url .= MT::Util::archive_file_for(undef, $blog,
            'Category', $cat);
        $tb->url($url);
        $tb->is_disabled(0);
        $tb->save
            or return $cat->error($tb->errstr);
    } else {
        ## If there is a TrackBack item for this category, but
        ## pings are now disabled, make sure that we mark the
        ## object as disabled.
        if (my $tb = MT::Trackback->load({
                                  category_id => $cat->id })) {
            $tb->is_disabled(1);
            $tb->save
                or return $cat->error($tb->errstr);
        }
    }
    1;
}

sub remove {
    my $cat = shift;
    require MT::Placement;
    my @place = MT::Placement->load({ category_id => $cat->id });
    for my $place (@place) {
        $place->remove;
    }
    require MT::Trackback;
    my @tb = MT::Trackback->load({ category_id => $cat->id });
    for my $tb (@tb) {
        $tb->remove;
    }
    $cat->SUPER::remove;
}

1;
__END__

=head1 NAME

MT::Category - Movable Type category record

=head1 SYNOPSIS

    use MT::Category;
    my $cat = MT::Category->new;
    $cat->blog_id($blog->id);
    $cat->label('My Category');
    $cat->save
        or die $cat->errstr;

=head1 DESCRIPTION

An I<MT::Category> object represents a category in the Movable Type system.
It is essentially a wrapper around the category label; by wrapping the label
in an object with a numeric ID, we can use the ID as a "foreign key" when
mapping entries into categories. Thus, if the category label changes, the
mappings don't break. This object does not contain any information about the
category-entry mappings--for those, look at the I<MT::Placement> object.

=head1 USAGE

As a subclass of I<MT::Object>, I<MT::Category> inherits all of the
data-management and -storage methods from that class; thus you should look
at the I<MT::Object> documentation for details about creating a new object,
loading an existing object, saving an object, etc.

=head1 DATA ACCESS METHODS

The I<MT::Category> object holds the following pieces of data. These fields
can be accessed and set using the standard data access methods described in
the I<MT::Object> documentation.

=over 4

=item * id

The numeric ID of the category.

=item * blog_id

The numeric ID of the blog to which this category belongs.

=item * label

The label of the category.

=item * author_id

The numeric ID of the author you created this category.

=back

=head1 DATA LOOKUP

In addition to numeric ID lookup, you can look up or sort records by any
combination of the following fields. See the I<load> documentation in
I<MT::Object> for more information.

=over 4

=item * blog_id

=item * label

=back

=head1 NOTES

=over 4

=item *

When you remove a category using I<MT::Category::remove>, in addition to
removing the category record, all of the entry-category mappings
(I<MT::Placement> objects) will be removed.

=back

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
