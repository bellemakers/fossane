# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: sqlite.pm,v 1.4 2003/02/12 00:15:08 btrott Exp $

package MT::ObjectDriver::DBI::sqlite;
use strict;

use Fcntl;

use MT::ObjectDriver::DBI;
@MT::ObjectDriver::DBI::sqlite::ISA = qw( MT::ObjectDriver::DBI );

sub init {
    my $driver = shift;
    $driver->SUPER::init(@_);
    my $cfg = $driver->cfg;
    my $db_file = $cfg->Database;
    ## This is ugly but necessary. SQLite only creates files with 0644
    ## permissions, so we can't use umask settings to modify those. So
    ## instead, we have to create the file if it doesn't exist in order
    ## to give it the proper permissions.
    unless (-e $db_file) {
        my $umask = oct $driver->cfg->DBUmask;
        my $old = umask($umask);
        local *JUNK;
        sysopen JUNK, $db_file, O_RDWR|O_CREAT, 0666
            or return $driver->error("Can't open '$db_file': $!");
        close JUNK;
        umask($old);
    }
    my $dsn = 'dbi:SQLite:dbname=' . $cfg->Database;
    $driver->{dbh} = DBI->connect($dsn, "", "",
        { RaiseError => 0, PrintError => 1 })
        or return $driver->error("Connection error: " . $DBI::errstr);
    $driver;
}

sub _prepare_from_where {
    my $driver = shift;
    my($class, $terms, $args) = @_;
    my($sql, @bind);

    ## Prefix the table name with 'mt_' to make it distinct.
    my $tbl = $class->datasource;
    my $tbl_name = 'mt_' . $tbl;

    my($w_sql, $w_terms, $w_bind) = ('', [], []);
    if (my $join = $args->{join}) {
        my($j_class, $j_col, $j_terms, $j_args) = @$join;
        my $j_tbl = $j_class->datasource;
        my $j_tbl_name = 'mt_' . $j_tbl;

        $sql = "from $tbl_name, $j_tbl_name\n";
        ($w_sql, $w_terms, $w_bind) =
            $driver->build_sql($j_class, $j_terms, $j_args, $j_tbl);
        push @$w_terms, "${tbl}_id = ${j_tbl}_$j_col";

        ## We are doing a join, but some args and terms may have been
        ## specified for the "outer" piece of the join--for example, if
        ## we are doing a join of entry and comments where we end up with
        ## entries, sorted by the created_on date in the entry table, or
        ## filtered by author ID. In that case the sort or author ID will
        ## be specified in the spec for the Entry load, not for the join
        ## load.
        my($o_sql, $o_terms, $o_bind) =
            $driver->build_sql($class, $terms, $args, $tbl);
        $w_sql .= $o_sql;
        if ($o_terms && @$o_terms) {
            push @$w_terms, @$o_terms;
            push @$w_bind, @$o_bind;
        }

        if (my $n = $j_args->{limit}) {
            $n =~ s/\D//g;   ## Get rid of any non-numerics.
            $w_sql .= sprintf "limit %d%s\n", $n,
                ($args->{offset} ? " offset $args->{offset}" : "");
        }
    } else {
        $sql = "from $tbl_name\n";
        ($w_sql, $w_terms, $w_bind) = $driver->build_sql($class, $terms, $args, $tbl);
    }
    $sql .= "where " . join(' and ', @$w_terms) . "\n" if @$w_terms;
    $sql .= $w_sql;
    @bind = @$w_bind;
    if (my $n = $args->{limit}) {
        $sql .= sprintf "limit %d%s\n", $n,
            ($args->{offset} ? " offset $args->{offset}" : "");
    }
    ($class->datasource, $sql, \@bind);
}

sub fetch_id { $_[0]->{dbh}->func('last_insert_rowid') }

1;
