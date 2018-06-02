#!/usr/bin/perl -w

# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mt-load.cgi,v 1.41 2003/02/14 00:17:28 btrott Exp $
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

local $| = 1;

print "Content-Type: text/html\n\n";
print "<pre>\n\n";

use File::Spec;

eval {

my $tmpl_list;
eval { $tmpl_list = require 'MT/default-templates.pl' };
die "Can't find default template list; where is 'default-templates.pl'?\n" .
    "Error: $@\n"
    if $@ || !$tmpl_list || ref($tmpl_list) ne 'ARRAY' || !@$tmpl_list;

print "Loading initial data into system...\n";

require MT;
my $mt = MT->new( Config => $MT_DIR . 'mt.cfg', Directory => $MT_DIR )
    or die MT->errstr;

if ($mt->{cfg}->ObjectDriver =~ /^DBI::(.*)$/) {
    my $type = $1;
    my $dbh = MT::Object->driver->{dbh};
    my $schema = File::Spec->catfile($MT_DIR, 'schemas', $type . '.dump');
    open FH, $schema or die "Can't open schema file '$schema': $!";
    my $ddl;
    { local $/; $ddl = <FH> }
    close FH;
    my @stmts = split /;/, $ddl;
    print "Loading database schema...\n\n";
    for my $stmt (@stmts) {
        $stmt =~ s!^\s*!!;
        $stmt =~ s!\s*$!!;
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }
}

require MT::Author;
require MT::Blog;

## First check if there are any authors or blogs currently--if there
## are, don't run the rest of the script, because we don't want to add
## the default author back in (hack).
if (MT::Author->count || MT::Blog->count) {
    print <<MSG, security_notice();

SYSTEM ALREADY INITIALIZED

It looks like your database has already been initialized by
mt-load.cgi. Re-running this script will create a security hole, so
I am stopping now.

MSG
    exit;
}

print "    Loading weblog...\n";
my $blog = MT::Blog->new;
$blog->name('First Weblog');
$blog->archive_type('Individual,Monthly');
$blog->archive_type_preferred('Individual');
$blog->days_on_index(7);
$blog->words_in_excerpt(40);
$blog->file_extension('html');
$blog->convert_paras(1);
$blog->convert_paras_comments(1);
$blog->sanitize_spec(0);
$blog->ping_weblogs(0);
$blog->ping_blogs(0);
$blog->server_offset(0);
$blog->allow_comments_default(1);
$blog->language('en');
$blog->sort_order_posts('descend');
$blog->sort_order_comments('ascend');
$blog->status_default(1);
$blog->save or die $blog->errstr;

print "    Loading author...\n";
my $author = MT::Author->new;
$author->name('Melody');
$author->set_password('Nelson');
$author->email('');
$author->can_create_blog(1);
$author->can_view_log(1);
$author->preferred_language('en-us');
$author->save or die $author->errstr;

print "    Loading permissions...\n";
require MT::Permission;
my $perms = MT::Permission->new;
$perms->author_id($author->id);
$perms->blog_id($blog->id);
$perms->set_full_permissions;
$perms->save or die $perms->errstr;

print "    Loading templates...\n";
require MT::Template;

my @arch_tmpl;
for my $val (@$tmpl_list) {
    $val->{text} = $mt->translate_templatized($val->{text});
    my $obj = MT::Template->new;
    $obj->set_values($val);
    $obj->blog_id($blog->id);
    $obj->save or die $obj->errstr;
    if ($val->{type} eq 'archive' || $val->{type} eq 'individual' ||
        $val->{type} eq 'category') {
        push @arch_tmpl, $obj;
    }
}

print "    Mapping templates to blog archive types...\n";
require MT::TemplateMap;

for my $tmpl (@arch_tmpl) {
    my(@at);
    if ($tmpl->type eq 'archive') {
        @at = qw( Daily Weekly Monthly );
    } elsif ($tmpl->type eq 'category') {
        @at = qw( Category );
    } elsif ($tmpl->type eq 'individual') {
        @at = qw( Individual );
    }
    for my $at (@at) {
        print "        Mapping template ID '", $tmpl->id, "' to '$at'\n";
        my $map = MT::TemplateMap->new;
        $map->archive_type($at);
        $map->is_preferred(1);
        $map->template_id($tmpl->id);
        $map->blog_id($tmpl->blog_id);
        $map->save
            or die "Save failed: ", $map->errstr;
    }
}

};
if ($@) {
    print <<HTML;

An error occurred while loading data:

$@

HTML
} else {
    print <<HTML, security_notice();

Done loading initial data! All went well.

HTML
}

print "</pre>\n";

sub security_notice {
    return <<TEXT;
VERY IMPORTANT NOTE:

Now that you have run mt-load.cgi, you will never need to run it
again. You should now delete mt-load.cgi from your webserver.

FAILURE TO DELETE mt-load.cgi INTRODUCES A MAJOR SECURITY RISK.
TEXT
}
