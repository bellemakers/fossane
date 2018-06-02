# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: ObjectDriver.pm,v 1.8 2003/02/12 00:15:03 btrott Exp $

package MT::ObjectDriver;
use strict;

use MT::ConfigMgr;

use MT::ErrorHandler;
@MT::ObjectDriver::ISA = qw( MT::ErrorHandler );

sub new {
    my $class = shift;
    my $type = shift;
    $class .= "::" . $type;
    eval "use $class;";
    die "Unsupported driver $class: $@" if $@;
    my $driver = bless {}, $class;
    $driver->init(@_) or return $class->error($driver->errstr);
    $driver;
}

sub init {
    my $driver = shift;
    $driver->{cfg} = MT::ConfigMgr->instance;
    $driver;
}

sub cfg { $_[0]->{cfg} }

sub load;
sub exists;
sub save;

1;
