#!/usr/bin/perl -w

# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mt-add-notify.cgi,v 1.11 2003/02/12 01:05:31 btrott Exp $
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

use CGI;
use MT::Notification;
use MT;

my $mt = MT->new( Config => $MT_DIR . 'mt.cfg',
                  Directory => $MT_DIR )
    or die MT->errstr;
my $q = CGI->new;

unless ($q->param('blog_id') && $q->param('email') &&
        $q->param('_redirect')) {
    print $q->header;
    print "Missing required parameters\n";
    exit;
}

my $note = MT::Notification->new;
$note->blog_id( $q->param('blog_id') );
$note->email( $q->param('email') );
$note->save;

print $q->redirect($q->param('_redirect'));
