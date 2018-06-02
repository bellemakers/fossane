# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mysql.pm,v 1.24 2003/02/12 00:15:08 btrott Exp $

package MT::ObjectDriver::DBI::mysql;
use strict;

use MT::ObjectDriver::DBI;
@MT::ObjectDriver::DBI::mysql::ISA = qw( MT::ObjectDriver::DBI );

use constant TEMP_TABLE => 'tempTable';

## We need to use a temporary table hack, and we drop the temporary
## table after we're done with it. So in on_load_complete, we need
## to know whether it's a temp table or not.
use vars qw( $IS_TMP );

## In MySQL, we only need to convert the created_on column;
## modified_on is a timestamp field, and it returns data in
## the format we expect.
sub date_cols { 'created_on' }
sub is_date_col { $_[1] eq 'created_on' }

sub db2ts {
    (my $ts = $_[1]) =~ tr/\- ://d;
    $ts;
}

sub fetch_id { $_[1]->{mysql_insertid} || $_[1]->{insertid} }

sub on_load_complete {
    my $driver = shift;
    my($sth) = @_;
    if ($IS_TMP) {
        $driver->{dbh}->do("drop table " . TEMP_TABLE);
        $IS_TMP = 0;
    }
}

sub init {
    my $driver = shift;
    $driver->SUPER::init(@_);
    my $cfg = $driver->cfg;
    my $dsn = 'dbi:mysql:database=' . $cfg->Database;
    $dsn .= ';hostname=' . $cfg->DBHost if $cfg->DBHost;
    $dsn .= ';mysql_socket=' . $cfg->DBSocket if $cfg->DBSocket;
    $driver->{dbh} = DBI->connect($dsn, $cfg->DBUser, $cfg->DBPassword,
        { RaiseError => 0, PrintError => 0 })
        or return $driver->error(MT->translate("Connection error: [_1]",
             $DBI::errstr));
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
    if (my $join = $args->{'join'}) {
        my($j_class, $j_col, $j_terms, $j_args) = @$join;
        my $j_tbl = $j_class->datasource;
        my $j_tbl_name = 'mt_' . $j_tbl;

        ## If we are doing a join where we want distinct and "order by",
        ## we need to use a temporary table to get around a bug in
        ## MySQL, and because MySQL doesn't support subselects.
        ## So we create a new temporary table, then adjust the
        ## returned SQL to select from that table.
        if ($j_args->{unique} && $j_args->{'sort'}) {
            ##     create temporary table tempTable
            ##     select <all foo cols>, <bar sort key> as temp_sort_key
            ##     from foo, bar
            ##     where foo.id = bar.foo_id
            my $dir = $j_args->{direction} eq 'descend' ? 'desc' : 'asc';
            my $ct_sql = "create temporary table " . TEMP_TABLE . "\nselect ";
            my $cols = $class->column_names;
            $ct_sql .= join(', ', map "${tbl}_$_ as " . TEMP_TABLE . "_$_", @$cols) .
                       ", ${j_tbl}_$j_args->{'sort'} as temp_sort_key\n";
            $ct_sql .= "from $tbl_name, $j_tbl_name\n";
            my($junk, $ct_terms, $ct_bind) =
                $driver->build_sql($j_class, $j_terms, $j_args, $j_tbl);
            push @$ct_terms, "(${tbl}_id = ${j_tbl}_$j_col)";
            $ct_sql .= "where " . join ' and ', @$ct_terms if @$ct_terms;
            $ct_sql .= " order by ${j_tbl}_$j_args->{'sort'} $dir";

            my $dbh = $driver->{dbh};
            my $sth = $dbh->prepare($ct_sql) or return;
            $sth->execute(@$ct_bind) or return;
            $sth->finish;

            ##     select distinct <all foo cols>
            ##     from tempTable
            ##     order by temp_sort_key <asc|desc>
            $sql = "from " . TEMP_TABLE . "\n";
            $w_sql = "order by temp_sort_key $dir\n";
            if (my $n = $j_args->{limit}) {
                $n =~ s/\D//g;   ## Get rid of any non-numerics.
                $w_sql .= sprintf "limit %s%d\n",
                    ($args->{offset} ? "$args->{offset}," : ""), $n;
            }
            $IS_TMP = 1;
        } else {
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
        }
    } else {
        $sql = "from $tbl_name\n";
        ($w_sql, $w_terms, $w_bind) = $driver->build_sql($class, $terms, $args, $tbl);
    }
    $sql .= "where " . join(' and ', @$w_terms) . "\n" if @$w_terms;
    $sql .= $w_sql;
    @bind = @$w_bind;
    if (my $n = $args->{limit}) {
        $n =~ s/\D//g;   ## Get rid of any non-numerics.
        $sql .= sprintf "limit %s%d\n",
            ($args->{offset} ? "$args->{offset}," : ""), $n;
    }
    ($IS_TMP ? TEMP_TABLE : $class->datasource, $sql, \@bind);
}

1;
