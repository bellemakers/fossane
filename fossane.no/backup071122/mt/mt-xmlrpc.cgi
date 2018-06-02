#!/usr/bin/perl -w

# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mt-xmlrpc.cgi,v 1.25 2003/02/12 01:05:31 btrott Exp $
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

use XMLRPC::Transport::HTTP;
use MT::XMLRPCServer;

$MT::XMLRPCServer::MT_DIR = $MT_DIR;

{
    ## Shut off warnings, because SOAP::Lite 0.55 causes some
    ## unitialized value warnings that seem to be connected to
    ## the soap->action
    local $SIG{__WARN__} = sub { };
    my $server = XMLRPC::Transport::HTTP::CGI->new;
    $server->dispatch_to('blogger', 'metaWeblog', 'mt');
    $server->handle;
}
