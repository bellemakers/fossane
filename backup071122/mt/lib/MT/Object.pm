# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Object.pm,v 1.22 2003/02/17 05:59:14 btrott Exp $

package MT::Object;
use strict;

use MT::ObjectDriver;
use MT::ErrorHandler;
@MT::Object::ISA = qw( MT::ErrorHandler );

## Magic.

sub install_properties {
    my $class = shift;
    no strict 'refs';
    ${"${class}::__properties"} = shift;
}

sub properties {
    my $this = shift;
    my $class = ref($this) || $this;
    no strict 'refs';
    ${"${class}::__properties"};
}

## Drivers.

use vars qw( $DRIVER );
sub set_driver { $DRIVER = MT::ObjectDriver->new($_[1]) }
sub driver { $DRIVER }

## Construction/initialization.

sub new {
    my $class = shift;
    my $obj = bless {}, $class;
    $obj->init(@_);
}

sub init {
    my $obj = shift;
    my %arg = @_;
    $obj->{'column_values'} = {};
    $obj;
}

sub clone {
    my $obj = shift;
    my $clone = ref($obj)->new();
    $clone->set_values($obj->column_values);
    $clone;
}

sub column_names {
    my $obj = shift;
    my $props = $obj->properties;
    my @cols = @{ $props->{columns} };
    push @cols, qw( created_on created_by modified_on modified_by )
        if $props->{audit};
    \@cols;
}

sub datasource { $_[0]->properties->{datasource} }

sub column_values { $_[0]->{'column_values'} }

sub column {
    my $obj = shift;
    my($col, $value) = @_;
    return unless defined $col;
    $obj->{'column_values'}->{$col} = $value if defined $value;
    $obj->{'column_values'}->{$col};
}

sub set_values {
    my $obj = shift;
    my($values) = @_;
    my @cols = @{ $obj->column_names };
    for my $col (@cols) {
        next unless exists $values->{$col};
        $obj->column($col, $values->{$col});
    }
}

sub _mk_passthru {
    my($method) = @_;
    sub {
        my($obj) = $_[0];
        die "No ObjectDriver defined" unless defined $DRIVER;
        if (wantarray) {
            my @rc = $DRIVER->$method(@_);
            @rc or return $obj->error( $DRIVER->errstr );
            return @rc;
        } else {
            my $rc = $DRIVER->$method(@_);
            defined $rc or return $obj->error( $DRIVER->errstr );
            return $rc;
        }
    }
}

{
    no strict 'refs';
    *load = _mk_passthru('load');
    *load_iter = _mk_passthru('load_iter');
    *save = _mk_passthru('save');
    *remove = _mk_passthru('remove');
    *remove_all = _mk_passthru('remove_all');
    *exists = _mk_passthru('exists');
    *count = _mk_passthru('count');
}

sub DESTROY { }

use vars qw( $AUTOLOAD );
sub AUTOLOAD {
    my $obj = $_[0];
    (my $col = $AUTOLOAD) =~ s!.+::!!;
    no strict 'refs';
    my $class = ref($obj);
    *$AUTOLOAD = sub {
        shift()->column($col, @_);
    };
    goto &$AUTOLOAD;
}

1;
__END__

=head1 NAME

MT::Object - Movable Type base class for database-backed objects

=head1 SYNOPSIS

Creating an I<MT::Object> subclass:

    package MT::Foo;
    use strict;

    use MT::Object;
    @MT::Foo::ISA = qw( MT::Object );
    __PACKAGE__->install_properties({
        columns => [
            'id', 'foo',
        ],
        indexes => {
            foo => 1,
        },
        datasource => 'foo',
    });

Using an I<MT::Object> subclass:

    use MT;
    use MT::Foo;

    ## Create an MT object to load the system configuration and
    ## initialize an object driver.
    my $mt = MT->new;

    ## Create an MT::Foo object, fill it with data, and save it;
    ## the object is saved using the object driver initialized above.
    my $foo = MT::Foo->new;
    $foo->foo('bar');
    $foo->save
        or die $foo->errstr;

=head1 DESCRIPTION

I<MT::Object> is the base class for all Movable Type objects that will be
serialized/stored to some location for later retrieval; this location could
be a DBM file, a relational database, etc.

Movable Type objects know nothing about how they are stored--they know only
of what types of data they consist, the names of those types of data (their
columns), etc. The actual storage mechanism is in the I<MT::ObjectDriver>
class and its driver subclasses; I<MT::Object> subclasses, on the other hand,
are essentially just standard in-memory Perl objects, but with a little extra
self-knowledge.

This distinction between storage and in-memory representation allows objects
to be serialized to disk in many different ways--for example, an object could
be stored in a MySQL database, in a DBM file, etc. Adding a new storage method
is as simple as writing an object driver--a non-trivial task, to be sure, but
one that will not require touching any other Movable Type code.

=head1 SUBCLASSING

Creating a subclass of I<MT::Object> is very simple; you simply need to
define the properties and metadata about the object you are creating. Start
by declaring your class, and inheriting from I<MT::Object>:

    package MT::Foo;
    use strict;

    use MT::Object;
    @MT::Foo::ISA = qw( MT::Object );

Then call the I<install_properties> method on your class name; an easy way
to get your class name is to use the special I<__PACKAGE__> variable:

    __PACKAGE__->install_properties({
        columns => [
            'id', 'foo',
        ],
        indexes => {
            foo => 1,
        },
        datasource => 'foo',
    });

I<install_properties> performs the necessary magic to install the metadata
about your new class in the MT system. The method takes one argument, a hash
reference containing the metadata about your class. That hash reference can
have the following keys:

=over 4

=item * columns

The definition of the columns (fields) in your object. Column names are also
used for method names for your object, so your column name should not
contain any strange characters. (It could also be used as part of the name of
the column in a relational database table, so that is another reason to keep
column names somewhat sane.)

The value for the I<columns> key should be a reference to an array containing
the names of your columns.

=item * indexes

Specifies the column indexes on your objects; this only has consequence for
some object drivers (DBM, for example), where indexes are not automatically
maintained by the datastore (as they are in a relational database).

The value for the I<indexes> key should be a reference to a hash containing
column names as keys, and the value C<1> for each key--each key represents
a column that should be indexed.

B<NOTE:> with the DBM driver, if you do not set up an index on a column you
will not be able to select objects with values matching that column using the
I<load> and I<load_iter> interfaces (see below).

=item * audit

Automatically adds bookkeeping capabilities to your class--each object will
take on four new columns: I<created_on>, I<created_by>, I<modified_on>, and
I<modified_by>. These columns will be filled automatically with the proper
values.

B<NOTE:> I<created_by> and I<modified_by> are not currently used.

=item * datasource

The name of the datasource for your class. The datasource is a name uniquely
identifying your class--it is used by the object drivers to construct table
names, file names, etc. So it should not be specific to any one driver.

=back

=head1 USAGE

=head2 System Initialization

Before using (loading, saving, removing) an I<MT::Object> class and its
objects, you must always initialize the Movable Type system. This is done
with the following lines of code:

    use MT;
    my $mt = MT->new;

Constructing a new I<MT> objects loads the system configuration from the
F<mt.cfg> configuration file, then initializes the object driver that will
be used to manage serialized objects.

=head2 Creating a new object

To create a new object of an I<MT::Object> class, use the I<new> method:

    my $foo = MT::Foo->new;

I<new> takes no arguments, and simply initializes a new in-memory object.
In fact, you need not ever save this object to disk; it can be used as a
purely in-memory object.

=head2 Setting and retrieving column values

To set the column value of an object, use the name of the column as a method
name, and pass in the value for the column:

    $foo->foo('bar');

The return value of the above call will be C<bar>, the value to which you have
set the column.

To retrieve the existing value of a column, call the same method, but without
an argument:

    $foo->foo

This returns the value of the I<foo> column from the I<$foo> object.

=head2 Saving an object

To save an object using the object driver, call the I<save> method:

    $foo->save;

On success, I<save> will return some true value; on failure, it will return
C<undef>, and you can retrieve the error message by calling the I<errstr>
method on the object:

    $foo->save
        or die "Saving foo failed: ", $foo->errstr;

If you are saving objects in a loop, take a look at the L<Note on Object
Locking>.

=head2 Loading an existing object or objects

You can load an object from the datastore using the I<load> method. I<load>
is by far the most complicated method, because there are many different ways
to load an object: by ID, by column value, by using a join with another type
of object, etc.

In addition, you can load objects either into an array (I<load>), or by using
an iterator to step through the objects (I<load_iter>).

I<load> has the following general form:

    my @objects = CLASS->load(\%terms, \%arguments);

I<load_iter> has the following general form:

    my $iter = CLASS->load_iter(\%terms, \%arguments);

Both methods share the same parameters; the only difference is the manner in
which they return the matching objects.

If you call I<load> in scalar context, only the first row of the array
I<@objects> will be returned; this works well when you know that your I<load>
call can only ever result in one object returned--for example, when you load
an object by ID.

I<\%terms> should be either:

=over 4

=item *

The numeric ID of an object in the datastore.

=item *

A reference to a hash where the keys are column names and the values are
the values for that column. For example, to load an I<MT::Foo> object where
the I<foo> column is equal to C<bar>, you could do this:

    my @foo = MT::Foo->load({ foo => 'bar' });

In addition to a simple scalar, the hash value can be a reference to an array;
combined with the I<range> setting in the I<\%arguments> list, you can use
this to perform range searches. If the value is a reference, the first element
in the array specifies the low end of the range, and the second element the
high end.

=back

I<\%arguments> should be a reference to a hash containing parameters for the
search. The following parameters are allowed:

=over 4

=item * sort => "column"

Sort the resulting objects by the column C<column>; C<column> must be an
indexed column (see L<indexes>, above).

=item * direction => "ascend|descend"

To be used together with I<sort>; specifies the sort order (ascending or
descending). The default is C<ascend>.

=item * limit => "N"

Rather than loading all of the matching objects (the default), load only
C<N> objects.

=item * offset => "M"

To be used together with I<limit>; rather than returning the first C<N>
matches (the default), return matches C<M> through C<N + M>.

=item * start_val => "value"

To be used together with I<limit> and I<sort>; rather than returning the
first C<N> matches, return the first C<N> matches where C<column> (the sort
column) is greater than C<value>.

=item * range

To be used together with an array reference as the value for a column in
I<\%terms>; specifies that the specific column should be searched for a range
of values, rather than one specific value.

The value of I<range> should be a hash reference, where the keys are column
names, and the values are all C<1>; each key specifies a column that should
be interpreted as a range.

=item * join

Can be used to select a set of objects based on criteria, or sorted by
criteria, from another set of objects. An example is selecting the C<N>
entries most recently commented-upon; the sorting is based on I<MT::Comment>
objects, but the objects returned are actually I<MT::Entry> objects. Using
I<join> in this situation is faster than loading the most recent
I<MT::Comment> objects, then loading each of the I<MT::Entry> objects
individually.

Note that I<join> is not a normal SQL join, in that the objects returned are
always of only one type--in the above example, the objects returned are only
I<MT::Entry> objects, and cannot include columns from I<MT::Comment> objects.

I<join> has the following general syntax:

    join => [ CLASS, JOIN_COLUMN, I<\%terms>, I<\%arguments> ]

I<CLASS> is the class with which you are performing the join; I<JOIN_COLUMN>
is the column joining the two object tables. I<\%terms> and I<\%arguments>
have the same meaning as they do in the outer I<load> or I<load_iter>
argument lists: they are used to select the objects with which the join is
performed.

For example, to select the last 10 most recently commmented-upon entries, you
could use the following statement:

    my @entries = MT::Entry->load(undef, {
        'join' => [ 'MT::Comment', 'entry_id',
                    { blog_id => $blog_id },
                    { 'sort' => 'created_on',
                      direction => 'descend',
                      unique => 1,
                      limit => 10 } ]
    });

In this statement, the I<unique> setting ensures that the I<MT::Entry>
objects returned are unique; if this flag were not given, two copies of the
same I<MT::Entry> could be returned, if two comments were made on the same
entry.

=item * unique

Ensures that the objects being returned are unique.

This is really only useful when used within a I<join>, because when loading
data out of a single object datastore, the objects are always going to be
unique.

=back

=head2 Removing an object

To remove an object from the datastore, call the I<remove> method on an
object that you have already loaded using I<load>:

    $foo->remove;

On success, I<remove> will return some true value; on failure, it will return
C<undef>, and you can retrieve the error message by calling the I<errstr>
method on the object:

    $foo->remove
        or die "Removing foo failed: ", $foo->errstr;

If you are removing objects in a loop, take a look at the L<Note on Object
Locking>.

=head2 Removing all of the objects of a particular class

To quickly remove all of the objects of a particular class, call the
I<remove_all> method on the class name in question:

    MT::Foo->remove_all;

On success, I<remove_all> will return some true value; on failure, it will
return C<undef>, and you can retrieve the error message by calling the
I<errstr> method on the class name:

    MT::Foo->remove_all
        or die "Removing all foo objects failed: ", MT::Foo->errstr;

=head2 Getting the count of a number of objects

To determine how many objects meeting a particular set of conditions exist,
use the I<count> method:

    my $count = MT::Foo->count({ foo => 'bar' });

I<count> takes the same arguments (I<\%terms> and I<\%arguments>) as I<load>
and I<load_iter>, above.

=head2 Determining if an object exists in the datastore

To check an object for existence in the datastore, use the I<exists> method:

    if ($foo->exists) {
        print "Foo $foo already exists!";
    }

=head1 NOTES

=head2 Note on object locking

When you read objects from the datastore, the object table is locked with a
shared lock; when you write to the datastore, the table is locked with an
exclusive lock.

Thus, note that saving or removing objects in the same loop where you are
loading them from an iterator will not work--the reason is that the datastore
maintains a shared lock on the object table while objects are being loaded
from the iterator, and thus the attempt to gain an exclusive lock when saving
or removing an object will cause deadlock.

For example, you cannot do the following:

    my $iter = MT::Foo->load_iter({ foo => 'bar' });
    while (my $foo = $iter->()) {
        $foo->remove;
    }

Instead you should do either this:

    my @foo = MT::Foo->load({ foo => 'bar' });
    for my $foo (@foo) {
        $foo->remove;
    }

or this:

    my $iter = MT::Foo->load_iter({ foo => 'bar' });
    my @to_remove;
    while (my $foo = $iter->()) {
        push @to_remove, $foo
            if SOME CONDITION;
    }
    for my $foo (@to_remove) {
        $foo->remove;
    }

This last example is useful if you will not be removing every I<MT::Foo>
object where I<foo> equals C<bar>, because it saves memory--only the
I<MT::Foo> objects that you will be deleting are kept in memory at the same
time.

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
