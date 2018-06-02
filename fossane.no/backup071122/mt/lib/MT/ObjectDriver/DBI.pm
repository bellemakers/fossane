# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: DBI.pm,v 1.5 2003/02/12 00:15:07 btrott Exp $

package MT::ObjectDriver::DBI;
use strict;

use DBI;

use MT::Util qw( offset_time_list );
use MT::ObjectDriver;
@MT::ObjectDriver::DBI::ISA = qw( MT::ObjectDriver );

sub generate_id { undef }
sub fetch_id { undef };
sub ts2db { $_[1] };
sub db2ts { $_[1] };

my %Date_Cols = map { $_ => 1 } qw( created_on modified_on );
sub is_date_col { $Date_Cols{$_[1]} }
sub date_cols { keys %Date_Cols }

sub on_load_complete { }

sub load_iter {
    my $driver = shift;
    my($class, $terms, $args) = @_;
    my($tbl, $sql, $bind) =
        $driver->_prepare_from_where($class, $terms, $args);
    my(%rec, @bind, @cols);
    my $cols = $class->column_names;
    for my $col (@$cols) {
        push @cols, $col;
        push @bind, \$rec{$col};
    }
    my $tmp = "select ";
    $tmp .= "distinct " if $args->{join} && $args->{join}[3]{unique};
    $tmp .= join(', ', map "${tbl}_$_", @cols) . "\n";
    $sql = $tmp . $sql;
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql) or return sub { };
    $sth->execute(@$bind) or return sub { };
    $sth->bind_columns(undef, @bind);
    sub {
        unless ($sth->fetch) {
            $sth->finish;
            $driver->on_load_complete($sth);
            return;
        }
        my $obj = $class->new;
        ## Convert DB timestamp format to our timestamp format.
        for my $col ($driver->date_cols) {
            $rec{$col} = $driver->db2ts($rec{$col}) if $rec{$col};
        }
        $obj->set_values(\%rec);
        $obj;
    };
}

sub load {
    my $driver = shift;
    my($class, $terms, $args) = @_;
    my($tbl, $sql, $bind) =
        $driver->_prepare_from_where($class, $terms, $args);
    my(%rec, @bind, @cols);
    my $cols = $class->column_names;
    for my $col (@$cols) {
        push @cols, $col;
        push @bind, \$rec{$col};
    }
    my $tmp = "select ";
    $tmp .= "distinct " if $args->{join} && $args->{join}[3]{unique};
    $tmp .= join(', ', map "${tbl}_$_", @cols) . "\n";
    $sql = $tmp . $sql;
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql) or return;
    $sth->execute(@$bind) or return;
    $sth->bind_columns(undef, @bind);
    my @objs;
    while ($sth->fetch) {
        my $obj = $class->new;
        ## Convert DB timestamp format to our timestamp format.
        for my $col ($driver->date_cols) {
            $rec{$col} = $driver->db2ts($rec{$col}) if $rec{$col};
        }
        $obj->set_values(\%rec);
        return $obj unless wantarray;
        push @objs, $obj;
    }
    $sth->finish;
    $driver->on_load_complete($sth);
    @objs;
}

sub count {
    my $driver = shift;
    my($class, $terms, $args) = @_;
    my($tbl, $sql, $bind) = $driver->_prepare_from_where($class, $terms, $args);
    ## Remove any order by clauses, because they will cause errors in
    ## some drivers (and they're not necessary)
    $sql =~ s/order by \w+ (?:asc|desc)//;
    $sql = "select count(*)\n" . $sql;
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql) or return;
    $sth->execute(@$bind) or return;
    $sth->bind_columns(undef, \my($count));
    $sth->fetch or return;
    $sth->finish;
    $driver->on_load_complete($sth);
    $count;
}

sub exists {
    my $driver = shift;
    my($obj) = @_;
    return unless $obj->id;
    my $tbl = $obj->datasource;
    my $sql = "select 1 from mt_$tbl where ${tbl}_id = ?";
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql) or return;
    $sth->execute($obj->id) or return;
    my $exists = $sth->fetch;
    $sth->finish;
    $exists;
}

sub save {
    my $driver = shift;
    my($obj) = @_;
    if ($driver->exists($obj)) {
        return $driver->update($obj);
    } else {
        return $driver->insert($obj);
    }
}

sub insert {
    my $driver = shift;
    my($obj) = @_;
    my $cols = $obj->column_names;
    unless ($obj->id) {
        ## If we don't already have an ID assigned for this object, we
        ## may need to generate one (depending on the underlying DB
        ## driver). If the driver gives us a new ID, we insert that into
        ## the new record; otherwise, we assume that the DB is using an
        ## auto-increment column of some sort, so we don't specify an ID
        ## at all.
        my $id = $driver->generate_id($obj);
        if ($id) {
            $obj->id($id);
        } else {
            $cols = [ grep $_ ne 'id', @$cols ];
        }
    }
    my $tbl = $obj->datasource;
    my $sql = "insert into mt_$tbl\n";
    $sql .= '(' . join(', ', map "${tbl}_$_", @$cols) . ')' . "\n" .
            'values (' . join(', ', ('?') x @$cols) . ')' . "\n";
    if ($obj->properties->{audit}) {
        my $blog_id = $obj->blog_id;
        my @ts = offset_time_list(time, $blog_id);
        my $ts = sprintf '%04d%02d%02d%02d%02d%02d',
            $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
        $obj->created_on($ts) unless $obj->created_on;
        $obj->modified_on($ts);
    }
    my @bind;
    for my $col (@$cols) {
        my $val = $obj->column($col);
        if ($driver->is_date_col($col)) {
            $val = $driver->ts2db($val);
        }
        push @bind, $val;
    }
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql)
        or return $driver->error($dbh->errstr);
    $sth->execute(@bind)
        or return $driver->error($dbh->errstr);
    $sth->finish;

    ## Now, if we didn't have an object ID, we need to grab the
    ## newly-assigned ID.
    unless ($obj->id) {
        $obj->id($driver->fetch_id($sth));
    }
    1;
}

sub update {
    my $driver = shift;
    my($obj) = @_;
    my $cols = $obj->column_names;
    $cols = [ grep $_ ne 'id', @$cols ];
    my $tbl = $obj->datasource;
    my $sql = "update mt_$tbl set\n";
    $sql .= join(', ', map "${tbl}_$_ = ?", @$cols) . "\n";
    $sql .= "where ${tbl}_id = '" . $obj->id . "'";
    if ($obj->properties->{audit}) {
        my $blog_id = $obj->blog_id;
        my @ts = offset_time_list(time, $blog_id);
        my $ts = sprintf "%04d%02d%02d%02d%02d%02d",
            $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
        $obj->modified_on($ts);
    }
    my @bind;
    for my $col (@$cols) {
        my $val = $obj->column($col);
        if ($driver->is_date_col($col)) {
            $val = $driver->ts2db($val);
        }
        push @bind, $val;
    }
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql)
        or return $driver->error($dbh->errstr);
    $sth->execute(@bind)
        or return $driver->error($dbh->errstr);
    $sth->finish;
    1;
}

sub remove {
    my $driver = shift;
    my($obj) = @_;
    my $id = $obj->id;
    return unless $id;
    my $tbl = $obj->datasource;
    my $sql = "delete from mt_$tbl where ${tbl}_id = ?";
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql)
        or return $driver->error($dbh->errstr);
    $sth->execute($id)
        or return $driver->error($dbh->errstr);
    $sth->finish;
    1;
}

sub remove_all {
    my $driver = shift;
    my($class) = @_;
    my $sql = "delete from mt_" . $class->datasource;
    my $dbh = $driver->{dbh};
    my $sth = $dbh->prepare($sql)
        or return $driver->error($dbh->errstr);
    $sth->execute
        or return $driver->error($dbh->errstr);
    $sth->finish;
    1;
}

sub DESTROY {
    $_[0]->{dbh}->disconnect if $_[0]->{dbh};
}

sub build_sql {
    my($driver, $class, $terms, $args, $tbl) = @_;
    my(@bind, @terms);
    if ($terms) {
        if (!ref($terms)) {
            return('', [ "${tbl}_id = ?" ], [ $terms ]);
        }
        for my $col (keys %$terms) {
            my $term = '';
            if (ref($terms->{$col}) eq 'ARRAY') {
                if ($args->{range} && $args->{range}{$col}) {
                    my($start, $end) = @{ $terms->{$col} };
                    if ($start) {
                        $term = "${tbl}_$col > ?";
                        push @bind,
                          $driver->is_date_col($col) ? $driver->ts2db($start) : $start;
                    }
                    $term .= " and " if $start && $end;
                    if ($end) {
                        $term .= "${tbl}_$col < ?";
                        push @bind,
                          $driver->is_date_col($col) ? $driver->ts2db($end) : $end;
                    }
                }
            } else {
                $term = "${tbl}_$col = ?";
                push @bind, $driver->is_date_col($col) ?
                    $driver->ts2db($terms->{$col}) : $terms->{$col};
            }
            push @terms, "($term)";
        }
    }
    if (my $sv = $args->{start_val}) {
        my $col = $args->{sort} || $driver->primary_key;
        my $cmp = $args->{direction} eq 'descend' ? '<' : '>';
        push @terms, "(${tbl}_$col $cmp ?)";
        push @bind, $driver->is_date_col($col) ? $driver->ts2db($sv) : $sv;
    }
    my $sql = '';
    if ($args->{'sort'} || $args->{direction}) {
        my $order = $args->{'sort'} || 'id';
        my $dir = $args->{direction} &&
                  $args->{direction} eq 'descend' ? 'desc' : 'asc';
        $sql .= "order by ${tbl}_$order $dir\n";
    }
    ($sql, \@terms, \@bind);
}

1;
