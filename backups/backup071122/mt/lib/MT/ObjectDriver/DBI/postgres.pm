# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: postgres.pm,v 1.7 2003/03/07 00:03:00 btrott Exp $

package MT::ObjectDriver::DBI::postgres;
use strict;

use MT::ObjectDriver::DBI;
@MT::ObjectDriver::DBI::postgres::ISA = qw( MT::ObjectDriver::DBI );

sub ts2db {
    sprintf '%04d-%02d-%02d %02d:%02d:%02d', unpack 'A4A2A2A2A2A2', $_[1];
}

sub db2ts {
    my $ts = $_[1];
    $ts =~ s/(?:\+|-)\d{2}$//;
    $ts =~ tr/\- ://d;
    $ts;
}

sub init {
    my $driver = shift;
    $driver->SUPER::init(@_);
    my $cfg = $driver->cfg;
    my $dsn = 'dbi:Pg:dbname=' . $cfg->Database;
    $dsn .= ';host=' . $cfg->DBHost if $cfg->DBHost;
    $dsn .= ';port=' . $cfg->DBPort if $cfg->DBPort;
    $driver->{dbh} = DBI->connect($dsn, $cfg->DBUser, $cfg->DBPassword,
        { RaiseError => 0, PrintError => 0 })
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

        if ($j_args->{unique} && $j_args->{'sort'}) {
            ## If it's a distinct with sorting, we need to create
            ## a subselect to select the proper set of rows.
            my $cols = $class->column_names;
            my $s_sql = "from (select " .
                        join(', ', map "${tbl}_$_", @$cols) .
                        ", ${j_tbl}_$j_args->{'sort'}\n";
            $sql = $s_sql . $sql;
            $w_sql .= ") t\n";
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

sub generate_id {
    my $driver = shift;
    my($class) = @_;
    my $seq = 'mt_' . $class->datasource . '_' .
              $class->properties->{primary_key};
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare("select nextval('$seq')")
        or return $driver->error($dbh->errstr);
    $sth->execute
        or return $driver->error($dbh->errstr);
    $sth->bind_columns(undef, \my($id));
    $sth->fetch;
    $sth->finish;
    $id;
}

1;
