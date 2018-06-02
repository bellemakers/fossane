#!/usr/bin/perl -w

# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mt-tb.cgi,v 1.3 2003/02/12 01:05:31 btrott Exp $
use strict;

my($MT_DIR);
BEGIN {
    if ($0 =~ m!(.*[/\\])!) {
        $MT_DIR = $1;
    } else {
        $MT_DIR = './';
    }
    unshift @INC, $MT_DIR . 'lib';
    unshift @INC, $MT_DIR . 'extlib';
}

eval {
    require MT::App::Trackback;
    my $app = MT::App::Trackback->new( Config => $MT_DIR . 'mt.cfg',
                                       Directory => $MT_DIR )
        or die MT::App::Trackback->errstr;
    local $SIG{__WARN__} = sub { $app->trace($_[0]) };
    $app->run;
};
if ($@) {
    print "Content-Type: text/html\n\n";
    print "An error occurred: $@";
}
