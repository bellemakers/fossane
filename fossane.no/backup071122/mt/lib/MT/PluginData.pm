# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: PluginData.pm,v 1.3 2003/02/12 00:15:03 btrott Exp $

package MT::PluginData;
use strict;

use Storable qw( freeze thaw );

use MT::Object;
@MT::PluginData::ISA = qw( MT::Object );
__PACKAGE__->install_properties ({
    columns => [
        'id', 'plugin', 'key', 'data',
    ],
    indexes => {
        plugin => 1,
        key => 1,
    },
    datasource => 'plugindata',
    primary_key => 'id',
});

sub data {
    my $data = shift;
    $data->column('data', freeze(shift)) if @_;
    thaw($data->column('data'));
} 

1;
__END__

=head1 NAME

MT::PluginData - Arbitrary data storage for Movable Type plugins

=head1 SYNOPSIS

    use MT::PluginData;
    my $data = MT::PluginData->new;
    $data->plugin('my-plugin');
    $data->key('unique-key');
    $data->data($big_data_structure);
    $data->save or die $data->errstr;

    ## ... later ...

    my $data = MT::PluginData->load({ plugin => 'my-plugin',
                                      key    => 'unique-key' });
    my $big_data_structure = $data->data;

=head1 DESCRIPTION

I<MT::PluginData> is a data storage mechanism for Movable Type plugins. It
uses the same backend datasource as the rest of the Movable Type system:
Berkeley DB, MySQL, etc. Plugins can use this class to store arbitrary
data structures in the database, keyed on a string specific to the plugin
and a key, just like a big associate array. Data structures are serialized
using I<Storable>.

=head1 USAGE

As a subclass of I<MT::Object>, I<MT::PluginData> inherits all of the
data-management and -storage methods from that class; thus you should look
at the I<MT::Object> documentation for details about creating a new object,
loading an existing object, saving an object, etc.

=head1 DATA ACCESS METHODS

The I<MT::PluginData> object holds the following pieces of data. These fields
can be accessed and set using the standard data access methods described in
the I<MT::Object> documentation.

=over 4

=item * id

The numeric ID of the record.

=item * plugin

A unique name identifying the plugin.

=item * key

A key--like the key in an associative array--that, with the I<plugin>
column, uniquely identifies this record.

=item * data

The data structure that is being stored. When setting the value for this
column, the value provided must be a reference. For example, the following
will die with an error:

    $data->data('string');

You must use

    $data->data(\'string');

instead.

=back

=head1 DATA LOOKUP

In addition to numeric ID lookup, you can look up or sort records by any
combination of the following fields. See the I<load> documentation in
I<MT::Object> for more information.

=over 4

=item * plugin

=item * key

=back

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
