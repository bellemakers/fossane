#!/usr/bin/perl -w

# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mt-check.cgi,v 1.24 2003/02/12 01:05:31 btrott Exp $
use strict;

local $|=1;

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

print "Content-Type: text/html\n\n";
print "<pre>\n";

my $is_good = 1;

my @REQ = (
    [ 'HTML::Template', 2, 1, 'HTML::Template is required for all Movable Type application functionality.' ],

    [ 'Image::Size', 0, 1, 'Image::Size is required for file uploads (to determine the size of uploaded images in many different formats).' ],

    [ 'File::Spec', 0.8, 1, 'File::Spec is required for path manipulation across operating systems.' ],

    [ 'CGI::Cookie', 0, 1, 'CGI::Cookie is required for cookie authentication.' ],
);

my @DATA = (
    [ 'DB_File', 0, 0, 'DB_File is required if you want to use the Berkeley DB/DB_File backend.' ],

    [ 'DBD::mysql', 0, 0, 'DBI and DBD::mysql are required if you want to use the MySQL database backend.' ],

    [ 'DBD::Pg', 0, 0, 'DBI and DBD::Pg are required if you want to use the PostgreSQL database backend.' ],

    [ 'DBD::SQLite', 0, 0, 'DBI and DBD::SQLite are required if you want to use the SQLite database backend.' ],
);

my @OPT = (
    [ 'LWP::UserAgent', 0, 0, 'LWP::UserAgent is optional; it is needed if you wish to use the TrackBack system, the weblogs.com ping, or the MT Recently Updated ping.' ],

    [ 'SOAP::Lite', 0.50, 0, 'SOAP::Lite is optional; it is needed if you wish to use the MT XML-RPC server implementation.' ],

    [ 'File::Temp', 0, 0, 'File::Temp is optional; it is needed if you would like to be able to overwrite existing files when you upload.' ],

    [ 'Image::Magick', 0, 0, 'Image::Magick is optional; it is needed if you would like to be able to create thumbnails of uploaded images.' ],
);

print <<HTML;
Movable Type [mt-check.cgi]

HTML

use Cwd;
my $cwd = '';
{
    my($bad);
    local $SIG{__WARN__} = sub { $bad++ };
    eval { $cwd = Cwd::getcwd() };
    if ($bad || $@) {
        eval { $cwd = Cwd::cwd() };
        if ($@ && $@ !~ /Insecure \$ENV{PATH}/) {
            die $@;
        }
    }
}

my $ver = $^V ? join('.', unpack 'C*', $^V) : $];
print <<INFO;
SYSTEM INFORMATION:

Current working directory: $cwd
Operating system: $^O
Perl version: $ver
INFO

## Try to create a new file in the current working directory. This
## isn't a perfect test for running under cgiwrap/suexec, but it
## is a pretty good test.
my $TMP = "test$$.tmp";
local *FH;
if (open(FH, ">$TMP")) {
    print "(Probably) Running under cgiwrap or suexec\n";
    unlink($TMP);
}

print "\n";

exit if $ENV{QUERY_STRING} && $ENV{QUERY_STRING} eq 'sys-check';

use Text::Wrap;
$Text::Wrap::columns = 72;

for my $list (\@REQ, \@DATA, \@OPT) {
    my $data = 1 if $list == \@DATA;
    my $req = 1 if $list == \@REQ;
    printf "CHECKING FOR %s MODULES:\n\n", $req ? "REQUIRED" :
        $data ? "DATA STORAGE" : "OPTIONAL";
    if (!$req && !$data) {
        print <<MSG;
The following modules are optional; if your server does not have these
modules installed, you only need to install them if you require the
functionality that the module provides.

MSG
    }
    if ($data) {
        print <<MSG;
The following modules are used by the different data storage options in
Movable Type. In order run the system, your server needs to have at least
one of these modules installed.

MSG
    }
    my $got_one_data = 0;
    for my $ref (@$list) {
        my($mod, $ver, $req, $desc) = @$ref;
        print "    $mod" .
            ($ver ? " (version &gt;= $ver)" : "") . "...\n";
        eval("use $mod" . ($ver ? " $ver;" : ";"));
        if ($@) {
            $is_good = 0 if $req;
            my $msg = $ver ?
                      "Either your server does not have $mod installed, or " .
                      "the version that is installed is too old. " :
                      "Your server does not have $mod installed. ";
            $msg   .= $desc .
                      " Please consult the installation instructions for " .
                      "help in installing $mod.";
            print wrap("        ", "        ", $msg), "\n\n";
        } else {
            print "        Your server has $mod installed (version @{[ $mod->VERSION ]}).\n\n";
            $got_one_data = 1 if $data;
        }
    }
    $is_good &= $got_one_data if $data;
    print "\n";
}

if ($is_good) {
    print <<HTML;
Your server has all of the required modules installed; you do not need to
perform any additional module installations. Continue with the installation
instructions.
HTML
}

print "</pre>\n";
