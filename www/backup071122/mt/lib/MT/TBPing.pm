# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: TBPing.pm,v 1.5 2003/04/04 06:02:42 btrott Exp $

package MT::TBPing;
use strict;

use MT::Object;
@MT::TBPing::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'blog_id', 'tb_id', 'title', 'excerpt', 'source_url', 'ip',
        'blog_name',
    ],
    indexes => {
        created_on => 1,
        blog_id => 1,
        tb_id => 1,
        ip => 1,
    },
    audit => 1,
    datasource => 'tbping',
    primary_key => 'id',
});

1;
__END__

=head1 NAME

MT::TBPing - Movable Type TrackBack Ping record

=head1 SYNOPSIS

    use MT::TBPing;
    my $ping = MT::TBPing->new;
    $ping->blog_id($tb->blog_id);
    $ping->tb_id($tb->id);
    $ping->title('Foo');
    $ping->excerpt('This is from a TrackBack ping.');
    $ping->source_url('http://www.foo.com/bar');
    $ping->save
        or die $ping->errstr;

=head1 DESCRIPTION

An I<MT::TBPing> object represents a TrackBack ping in the Movable Type system.
It contains all of the metadata about the ping (title, excerpt, URL, etc).

=head1 USAGE

As a subclass of I<MT::Object>, I<MT::TBPing> inherits all of the
data-management and -storage methods from that class; thus you should look
at the I<MT::Object> documentation for details about creating a new object,
loading an existing object, saving an object, etc.

=head1 DATA ACCESS METHODS

The I<MT::TBPing> object holds the following pieces of data. These fields can
be accessed and set using the standard data access methods described in the
I<MT::Object> documentation.

=over 4

=item * id

The numeric ID of the ping.

=item * blog_id

The numeric ID of the blog in which the ping is found.

=item * tb_id

The numeric ID of the TrackBack record (I<MT::Trackback> object) to which
the ping was sent.

=item * title

The title of the ping item.

=item * ip

The IP address of the server that sent the ping.

=item * excerpt

The excerpt of the ping item.

=item * source_url

The URL of the item pointed to by the ping.

=item * blog_name

The name of the blog on which the original item was posted.

=item * created_on

The timestamp denoting when the ping record was created, in the format
C<YYYYMMDDHHMMSS>. Note that the timestamp has already been adjusted for the
selected timezone.

=item * modified_on

The timestamp denoting when the ping record was last modified, in the
format C<YYYYMMDDHHMMSS>. Note that the timestamp has already been adjusted
for the selected timezone.

=back

=head1 DATA LOOKUP

In addition to numeric ID lookup, you can look up or sort records by any
combination of the following fields. See the I<load> documentation in
I<MT::Object> for more information.

=over 4

=item * created_on

=item * tb_id

=item * blog_id

=item * ip

=back

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
