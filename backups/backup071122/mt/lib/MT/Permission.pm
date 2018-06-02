# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Permission.pm,v 1.21 2003/02/12 00:15:03 btrott Exp $

package MT::Permission;
use strict;

use MT::Object;
@MT::Permission::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    columns => [
        'id', 'author_id', 'blog_id', 'role_mask', 'entry_prefs',
    ],
    indexes => {
        blog_id => 1,
        author_id => 1,
    },
    datasource => 'permission',
    primary_key => 'id',
});

{
    my @Perms = (
#        [ 1, 'login', 'Login', ],
        [ 2, 'post', 'Post', ],
        [ 4, 'upload', 'Upload File', ],
        [ 8, 'edit_all_posts', 'Edit All Posts', ],
        [ 16, 'edit_templates', 'Edit Templates', ],
        [ 32, 'edit_authors', 'Edit Authors & Permissions', ],
        [ 64, 'edit_config', 'Configure Weblog', ],
        [ 128, 'rebuild', 'Rebuild Files', ],
        [ 256, 'send_notifications', 'Send Notifications', ],
        [ 512, 'edit_categories', 'Edit Categories', ],
        [ 1024, 'edit_notifications', 'Edit Address Book' ],
    );

    sub set_full_permissions {
        my $perms = shift;
        my $mask = 0;
        for my $ref (@Perms) {
            $mask += $ref->[0];
        }
        $perms->role_mask($mask);
    }

    sub perms { \@Perms }

    no strict 'refs';
    for my $ref (@Perms) {
        my $mask = $ref->[0];
        my $meth = 'can_' . $ref->[1];
        *$meth = sub {
            my $flags = $_[0]->role_mask || 0;
            if (@_ == 2) {
                $flags = $_[1] ? ($flags | $mask) :
                                 ($flags & ~$mask);
                $_[0]->role_mask($flags);
            }
            $flags & $mask;
        };
    }
}

sub can_edit_entry {
    my $perms = shift;
    my($entry, $author) = @_;
    $perms->can_edit_all_posts ||
    ($perms->can_post &&
    $entry->author_id == $author->id);
}

1;
__END__

=head1 NAME

MT::Permission - Movable Type permissions record

=head1 SYNOPSIS

    use MT::Permission;
    my $perms = MT::Permission->load({ blog_id => $blog->id,
                                       author_id => $author->id })
        or die "Author has no permissions for blog";
    $perms->can_post
        or die "Author cannot post to blog";

    $perms->can_edit_config(0);
    $perms->save
        or die $perms->errstr;

=head1 DESCRIPTION

An I<MT::Permission> object represents the permissions settings for an author
in a particular blog. Permissions are set on a role basis, and each permission
is either on or off for an author-blog combination; permissions are stored as
a bitmask.

=head1 USAGE

As a subclass of I<MT::Object>, I<MT::Permission> inherits all of the
data-management and -storage methods from that class; thus you should look
at the I<MT::Object> documentation for details about creating a new object,
loading an existing object, saving an object, etc.

The following methods are unique to the I<MT::Permission> interface. Each of
these methods, B<except> for I<set_full_permissions>, can be called with an
optional argument to turn the permission on or off. If the argument is some
true value, the permission is enabled; otherwise, the permission is disabled.
If no argument is provided at all, the existing permission setting is
returned.

=head2 $perms->set_full_permissions

Turns on all permissions for the author and blog represented by I<$perms>.

=head2 $perms->can_post

Returns true if the author can post to the blog, and edit the entries that
he/she has posted; false otherwise.

=head2 $perms->can_upload

Returns true if the author can upload files to the blog directories specified
for this blog, false otherwise.

=head2 $perms->can_edit_all_posts

Returns true if the author can edit B<all> entries posted to this blog (even
entries that he/she did not write), false otherwise.

=head2 $perms->can_edit_templates

Returns true if the author can edit the blog's templates, false otherwise.

=head2 $perms->can_send_notifications

Returns true if the author can send messages to the notification list, false
otherwise.

=head2 $perms->can_edit_categories

Returns true if the author can edit the categories defined for the blog, false
otherwise.

=head2 $perms->can_edit_notifications

Returns true if the author can edit the notification list for the blog, false
otherwise.

=head2 $perms->can_edit_authors

Returns true if the author can edit author permissions for the blog, and add
new authors who have access to the blog; false otherwise.

Note: you should be very careful when giving this permission to authors,
because an author could easily then block your access to the blog.

=head2 $perms->can_edit_config

Returns true if the author can edit the blog configuration, false otherwise.
Note that this setting also controls whether the author can import entries
to the blog, and export entries from the blog.

=head1 DATA ACCESS METHODS

The I<MT::Comment> object holds the following pieces of data. These fields can
be accessed and set using the standard data access methods described in the
I<MT::Object> documentation.

=over 4

=item * id

The numeric ID of this permissions record.

=item * author_id

The numeric ID of the author associated with this permissions record.

=item * blog_id

The numeric ID of the blog associated with this permissions record.

=item * role_mask

The permissions bitmask. You should not access this value directly; instead
use the I<can_*> methods, above.

=back

=head1 DATA LOOKUP

In addition to numeric ID lookup, you can look up or sort records by any
combination of the following fields. See the I<load> documentation in
I<MT::Object> for more information.

=over 4

=item * blog_id

=item * author_id

=back

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
