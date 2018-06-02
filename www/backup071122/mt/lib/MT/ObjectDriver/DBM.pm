# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: DBM.pm,v 1.61 2003/02/12 00:15:07 btrott Exp $

package MT::ObjectDriver::DBM;
use strict;

use DB_File;
use Fcntl qw( :flock );
use Symbol;
use File::Spec;

use MT::Util qw( offset_time_list );
use MT::Serialize;
use MT::ObjectDriver;
@MT::ObjectDriver::DBM::ISA = qw( MT::ObjectDriver );

sub init {
    my $driver = shift;
    $driver->SUPER::init(@_);
    $driver->{serializer} = MT::Serialize->new($driver->cfg->Serializer);
    my $dir = $driver->cfg->DataSource;
    unless (-d $dir) {
        return $driver->error(MT->translate(
            "Your DataSource directory ('[_1]') does not exist.", $dir));
    }
    $driver;
}

sub _db_data {
    File::Spec->catfile($_[0]->cfg->DataSource,
        $_[1]->datasource . ".db");
}

sub _db_index {
    File::Spec->catfile($_[0]->cfg->DataSource, $_[1]->datasource .
        '.' . $_[2] . '.idx');
}

sub _lock {
    my $driver = shift;
    my($file, $o_mode) = @_;
    my $lock_name = "$file.lock";
    if ($driver->cfg->NoLocking) {
        ## If the user doesn't want locking, don't try to lock anything.
        return sub { };
    } elsif ($driver->cfg->UseNFSSafeLocking) {
        ## If we are using NFS-safe locking, don't worry about locking
        ## when we are reading files, because there is no way of doing
        ## atomic shared + exclusive locking using .lock files.
        return sub { } unless $o_mode eq 'rw';

        require Sys::Hostname;
        my $hostname = Sys::Hostname::hostname();
        my $lock_tmp = $lock_name . '.' . $hostname . '.' . $$;
        my $max_lock_age = 60;    ## no. of seconds til we break the lock
        my $tries = 10;           ## no. of seconds to keep trying
        my $lock_fh = gensym();
        open $lock_fh, ">$lock_tmp" or return;
        select((select($lock_fh), $|=1)[0]);  ## Turn off buffering
        my $got_lock = 0;
        for (0..$tries-1) {
            print $lock_fh $$, "\n"; ## Update modified time on lockfile
            if (link($lock_tmp, $lock_name)) {
                $got_lock++; last;
            } elsif ((stat $lock_tmp)[3] > 1) {
                ## link() failed, but the file exists--we got the lock.
                $got_lock++; last;
            } else {
                ## Couldn't get a lock; if the lock is too old, break it.
                my $lock_age = (stat $lock_name)[10];
                unlink $lock_name if time - $lock_age > $max_lock_age;
            }
            sleep 1;
        }
        close $lock_fh;
        unlink $lock_tmp;
        return unless $got_lock;
        return sub { unlink $lock_name };
    } else {
        my $lock_fh = gensym();
        sysopen $lock_fh, $lock_name, O_RDWR|O_CREAT, 0666
            or return;
        my $lock_flags = $o_mode eq 'rw' ? LOCK_EX : LOCK_SH;
        unless (flock $lock_fh, $lock_flags) {
            close $lock_fh;
            return;
        }
        return sub { close $lock_fh };
    }
}

sub _tie_db_file {
    my $driver = shift;
    my($file, $type, $o_mode) = @_;
    my $flag = $o_mode && $o_mode eq 'rw' ? O_RDWR|O_CREAT : O_RDONLY;
    my $umask = oct $driver->cfg->DBUmask;
    my $old = umask($umask);
    my $unlock = $driver->_lock($file, $o_mode)
        or return;
    my $DB = tie my %db, 'DB_File', $file, $flag, 0666, $type;
    unless ($DB) {
        $unlock->();
        return;
    }
    umask($old);
    ($DB, \%db, $unlock);
}

sub _get_ids {
    my $driver = shift;
    my($DB, $db, $class, $terms, $args) = @_;
    my @ids;
    my($extract_join_col, $filter_results);
    if ($args && $args->{'join'}) {  ## Lookup using table join
        @ids = $driver->_get_ids_join($DB, $db, $class, $terms, $args);
        $filter_results = 1;
    }
    elsif ($args && $args->{limit}) {    ## Lookup with limit
        @ids = $driver->_get_ids_limit($DB, $db, $class, $terms, $args);
    }
    elsif ($terms) {                  ## Lookup using index or ID
        if (ref($terms) eq 'HASH') {
            @ids = %$terms ?
                $driver->_get_ids_from_index($DB, $db, $class, $terms, $args) :
                keys %$db;
            if ($args->{join_col}) {
                $extract_join_col = 1;
            }
        } else {
            @ids = $terms;
        }
    }
    else {                          ## Lookup all
        if ($args->{join_col}) {
            $extract_join_col = 1;
        }
        @ids = keys %$db;
    }

    ## Now sort if we need to, by sort column. If limit is provided along
    ## with sort, we have already sorted in _get_ids_limit, so we don't
    ## need to do it again--except in the case where a join was used.
    if ((my $col = $args->{'sort'}) && (!$args->{limit} || $args->{'join'})) {
        my $direction = $args->{direction} || 'ascend';
        my $idx_file = _db_index($driver, $class, $col);
        my($DB, $idx, $unlock) =
            $driver->_tie_db_file($idx_file, $DB_BTREE, 'r')
            or return $driver->error(MT->translate(
                "Tie '[_1]' failed: [_2]", $idx_file, "$!" ));
        my %sort_val = map { $_ => '' } @ids;
        while (my($val, $ids) = each(%$idx)) {
            my @idx_ids = split /$;/, $ids;
            @sort_val{ @idx_ids } = ($val) x @idx_ids;
        }
        @ids = $direction eq 'ascend' ?
            (sort { $sort_val{$a} cmp $sort_val{$b} } @ids) :
            (sort { $sort_val{$b} cmp $sort_val{$a} } @ids);
        undef $DB;
        untie %$idx;
        $unlock->();
    }

    ## Now, if have a $join_col, it means that we want a different
    ## column from the record than its ID. So we need to loop through
    ## the matched record IDs and grab the column values.
    if ($extract_join_col || $filter_results) {
        my $join_col = $args->{join_col};
        my @final;
        for my $id (@ids) {
            my $rec = $db->{$id};
            $rec = ${ $driver->{serializer}->unserialize($rec) };
            if ($filter_results) {
                my $matched = 1;
                for my $col (keys %$terms) {
                    $matched = 0, last unless defined $rec->{$col};
                    if ($args->{range}{$col}) {
                        my($start, $end) = @{ $terms->{$col} }; 
                        $matched = 0, last   
                            unless ((!$start || $rec->{$col} >= $start) &&
                                    (!$end   || $rec->{$col} <= $end));
                    } else {
                        $matched = 0, last
                            unless $terms->{$col} eq $rec->{$col};
                    }
                }
                next unless $matched;
            }
            push @final, $join_col ? $rec->{$join_col} : $id;
        }
        @ids = @final;
    }

    ## If we want to ensure unique IDs, do that here. Note that we don't
    ## need to do this if we are getting IDs by limit, because we will
    ## have already guaranteed uniqueness in _get_ids_limit.
    if ($args->{unique} && (!$args->{limit} || $args->{'join'})) {
        my %h;
        @ids = grep !$h{$_}++, @ids;
    }

    ## If we have set a limit, and we have used a join, then the limit
    ## on the outer lookup will not have been applied yet. So we need to
    ## apply that here.
    if ((my $n = $args->{limit}) && $args->{'join'}) {
        my $off = $args->{offset} || 0;
        my $max = @ids > $n + $off ? $n + $off : @ids;
        @ids = @ids[$off..$max-1];
    }

    @ids;
}

sub _get_ids_join {
    my $driver = shift;
    my($DB, $db, $class, $terms, $args) = @_;
    my $join = $args->{'join'};
    $join->[3]{join_col} = $join->[1];
    splice @$join, 1, 1;

    ## 1. Open up DB that we are joining with.
    my $db_file = _db_data($driver, $join->[0]);
    my($JOIN_DB, $join_db, $unlock) =
        $driver->_tie_db_file($db_file, $DB_BTREE, 'r')
        or return $driver->error(MT->translate(
            "Tie '[_1]' failed: [_2]", $db_file, "$!" ));

    ## 2. Call _get_ids with the opened join DB and the join params. For each
    ## matched record, we actually get back the join_col value, not the record
    ## ID. These values are then used as the list of IDs for the $class we want.
    my @ids = $driver->_get_ids($JOIN_DB, $join_db, @$join);

    undef $JOIN_DB;
    untie %$join_db;
    $unlock->();

    @ids;
}

sub _get_ids_from_index {
    my $driver = shift;
    my($DB, $db, $class, $terms, $args) = @_;
    my %count;
    for my $col (keys %$terms) {
        my $idx_file = _db_index($driver, $class, $col);
        my($IDX, $idx, $unlock) =
            $driver->_tie_db_file($idx_file, $DB_BTREE, 'r')
            or return $driver->error(MT->translate(
                "Tie '[_1]' failed: [_2]", $idx_file, "$!" ));
        my @ids;
        if (ref($terms->{$col}) eq 'ARRAY') {
            if ($args->{range} && $args->{range}{$col}) {   ## Range lookup
                my($start, $end) = @{ $terms->{$col} };
                my($key, $val) = ($start, 0);
                unless ($IDX->seq($key, $val, R_CURSOR)) {
                    @ids = split /$;/, $val || '';
                    my($st);
                    for ($st = $IDX->seq($key, $val, R_NEXT);
                         $st == 0 && (!$end || $key < $end);
                         $st = $IDX->seq($key, $val, R_NEXT)) {
                        push @ids, split /$;/, $val || '';
                    }
                }
            }
        }
        else {                                 ## Standard 'equals' lookup
            my $col_value = $terms->{$col};
            $col_value = '' unless defined $col_value;
            @ids = split /$;/, $idx->{$col_value} || '';
        }
        undef $IDX;
        untie %$idx;
        $unlock->();
        for my $id (@ids) { $count{$id}++ }
    }
    my @ids;
    my $num_cols = scalar keys %$terms;
    for my $id (keys %count) {
        push @ids, $id if $count{$id} >= $num_cols;
    }
    @ids;
}

sub _get_ids_limit {
    my $driver = shift;
    my($DB, $db, $class, $terms, $args) = @_;
    my $n = $args->{limit};
    my $this_db = $DB;
    my $idx;
    my(%ids, @ids);
    my $unlock;
    if (my $col = $args->{'sort'}) {
        my $idx_file = _db_index($driver, $class, $col);
        ($this_db, $idx, $unlock) =
            $driver->_tie_db_file($idx_file, $DB_BTREE, 'r')
            or return $driver->error(MT->translate(
                "Tie '[_1]' failed: [_2]", $idx_file, "$!" ));
    }
    my $dir = $args->{direction} || 'ascend';
    my($c1, $c2) = $dir eq 'ascend' ? (R_FIRST, R_NEXT) :
                                      (R_LAST,  R_PREV);
    my $join_col = $args->{join_col};
    my $uniq = $args->{unique};
    my($i, $j, $key, $val, $st) = (0, 0, 0, 0);
    my $offset = $args->{offset};
    if (my $start_val = $args->{start_val}) {
        ## Advance cursor to start val
        $c1 = $dir eq 'ascend' ? R_NEXT : R_PREV;
        $st = $this_db->seq($args->{start_val}, $val, R_CURSOR);

        ## The only situation where the above match will fail (and
        ## $st != 0) is where our start_val is greater than any of
        ## the keys in the DB. In that situation, there are two
        ## alternatives: 1) if we are looking for a descending sort, it's
        ## fine if the match failed, because R_PREV will give us the
        ## "greatest" key; 2) if we are looking for an ascending sort,
        ## we know there are no "greater" keys, so we give up.
        if ($st && $dir eq 'ascend') {
            if ($args->{'sort'}) {
                undef $this_db;
                untie %$idx;
                $unlock->();
            }
            return;
        }

        ## If this is an ascending lookup, and we don't have an exact
        ## match for the start value, we need to rewind the cursor,
        ## because it has already hit the "next" record in line, and we
        ## want that next record to be uncovered by the loop below so
        ## that it is marked as a match.
        if ($dir eq 'ascend') {
            my $tied_db = $idx ? $idx : $db;
            if (!exists $tied_db->{$start_val}) {
                my($tmp1, $tmp2) = (0, 0);
                $this_db->seq($tmp1, $tmp2, R_PREV);
            }
        }
    }
    ## Iterate through records until we have found $n (limit) matches.
    ## $i counts the number of matches we have found thus far, but we
    ## only start incrementing $i until after we have found $offset
    ## matches. $j counts the number of matches we have found until we
    ## reach $offset.
    for ($st = $this_db->seq($key, $val, $c1);
        $st == 0 && $i < $n;
        $st = $this_db->seq($key, $val, $c2)) {

        ## If we have a sort key, that means we are using an index, so
        ## the list of IDs is found by splitting the index value; otherwise,
        ## we are iterating over the actual database, so the ID is just the
        ## DB key.
        my @these_ids = $args->{'sort'} ? split(/$;/, $val) : $key;

        ## If we are looking for records with specific criteria ($terms),
        ## we need to check these records to see if they match.
        my @matched_ids;
        if ($terms) {
            unless ($args->{'sort'}) {
                my $rec = ${ $driver->{serializer}->unserialize($val) };
                my $matched = 1;
                for my $col (keys %$terms) {
                    $matched = 0, last
                        unless defined($rec->{$col}) &&
                            $terms->{$col} eq $rec->{$col};
                }
                push(@matched_ids, $join_col ? $rec->{$join_col} : $key)
                    if $matched;
            } else {
                for my $id (@these_ids) {
                    my $rec = $db->{$id} or next;
                    $rec = ${ $driver->{serializer}->unserialize($rec) };
                    my $matched = 1;
                    for my $col (keys %$terms) {
                        $matched = 0, last
                            unless defined($rec->{$col}) &&
                                $terms->{$col} eq $rec->{$col};
                    }
                    push(@matched_ids, $join_col ? $rec->{$join_col} : $id)
                        if $matched;
                }
            }
        }
        ## Otherwise we can just add these records to the list of
        ## matches.
        else {
            for my $id (@these_ids) {
                ## We could let the conditional below handle this, but
                ## it is faster if we handle it here: this way, if we
                ## are using $join_col, we don't have to pull out the
                ## record and unserialize it.
                if ($offset && $j < $offset) {
                    $j++;
                    next;
                }
                if ($join_col) {
                    my $rec = $db->{$id} or next;
                    $rec = ${ $driver->{serializer}->unserialize($rec) };
                    push @matched_ids, $rec->{$join_col};
                } else {
                    push @matched_ids, $id;
                }
            }
        }

        ## Now, loop over all of the matching IDs. If an offset is specified,
        ## and we have not yet reached that offset, we skip the ID; otherwise
        ## we add the ID to the final list.
        for my $id (@matched_ids) {
            if ($offset && $j < $offset) {
                $j++;
            } else {
                if (!$uniq || !exists $ids{$id}) {
                    push @ids, $id;
                    $ids{$id}++;
                    $i++;
                }
            }
        }
    }
    if ($args->{'sort'}) {
        undef $this_db;
        untie %$idx;
        $unlock->();
    }
    @ids;
}

sub load_iter {
    my $driver = shift;
    my($class, $terms, $args) = @_;
    my $db_file = _db_data($driver, $class);
    my($DB, $db, $unlock) = $driver->_tie_db_file($db_file, $DB_BTREE, 'r')
        or return sub { };
    my @ids = $driver->_get_ids($DB, $db, $class, $terms, $args);
    my $idx = 0;
    sub {
        if ($idx > $#ids) {
            undef $DB;
            untie %$db;
            $unlock->();
            return;
        }
        my $rec = $db->{ $ids[$idx++] } or return;
        $rec = $driver->{serializer}->unserialize($rec);
        my $obj = $class->new;
        $obj->set_values($$rec);
        $obj;
    };
}

sub load {
    my $driver = shift;
    my($class, $terms, $args) = @_;
    my $db_file = _db_data($driver, $class);
    my($DB, $db, $unlock) = $driver->_tie_db_file($db_file, $DB_BTREE, 'r')
        or return;
    my @ids = $driver->_get_ids($DB, $db, $class, $terms, $args);
    my @objs;
    for my $id (@ids) {
        my $rec = $db->{$id} or return;
        $rec = $driver->{serializer}->unserialize($rec);
        my $obj = $class->new;
        $obj->set_values($$rec);
        $unlock->(), return($obj) unless wantarray;
        push @objs, $obj;
    }
    undef $DB;
    untie %$db;
    $unlock->();
    @objs;
}

sub count {
    my $driver = shift;
    my($class, $terms, $args) = @_;
    my $db_file = _db_data($driver, $class);
    my($DB, $db, $unlock) = $driver->_tie_db_file($db_file, $DB_BTREE, 'r')
        or return 0;
    my @ids = $driver->_get_ids($DB, $db, $class, $terms, $args);
    undef $DB;
    untie %$db;
    $unlock->();
    scalar @ids;
}

sub exists {
    my $driver = shift;
    my($obj) = @_;
    return unless $obj->id;
    my $db_file = _db_data($driver, $obj);
    my($DB, $db, $unlock) = $driver->_tie_db_file($db_file, $DB_BTREE, 'r')
        or return 0;
    my $exists = exists $db->{$obj->id};
    undef $DB;
    untie %$db;
    $unlock->();
    $exists;
}

sub save {
    my $driver = shift;
    my($obj) = @_;
    my $db_file = _db_data($driver, $obj);
    my($DB, $db, $unlock) = $driver->_tie_db_file($db_file, $DB_BTREE, 'rw')
        or return $driver->error(MT->translate(
            "Tie '[_1]' failed: [_2]", $db_file, "$!" ));
    unless ($obj->id || ($obj->id($driver->generate_id($obj)))) {
        return $driver->error(MT->translate(
            "Failed to generate unique ID: [_1]", $driver->errstr ));
    }
    my $id = $obj->id;
    if ($obj->properties->{audit}) {
        my $blog_id = $obj->blog_id;
        my @ts = offset_time_list(time, $blog_id);
        my $ts = sprintf "%04d%02d%02d%02d%02d%02d",
            $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
        $obj->created_on($ts)
            unless CORE::exists($db->{$id}) || $obj->created_on;
        $obj->modified_on($ts);
    }
    ## Grab old values so that we can update indexes on changed columns
    my $old = $db->{$id};
    $old = ${ $driver->{serializer}->unserialize($old) } if $old;
    $db->{$id} = $driver->{serializer}->serialize(\$obj->column_values);
    undef $DB;
    untie %$db;
    $unlock->();

    my $indexes = $obj->properties->{indexes};
    for my $col (keys %$indexes) {
        my $idx_file = _db_index($driver, $obj, $col);
        my($DB, $idx, $unlock) =
            $driver->_tie_db_file($idx_file, $DB_BTREE, 'rw')
            or return $driver->error(MT->translate(
                "Tie '[_1]' failed: [_2]", $idx_file, "$!" ));
        my $col_value = $obj->$col();
        $col_value = '' unless defined $col_value;
        my %ids = map { $_ => 1 } split /$;/, $idx->{$col_value} || '';
        $unlock->(), next if exists $ids{$id};
        $idx->{$col_value} = join $;, keys %ids, $id;
        $old->{$col} = '' unless !$old || defined $old->{$col};
        if ($old && $old->{$col} ne $col_value) {
            _drop_from_index($idx, $id, $old->{$col});
        }
        undef $DB;
        untie %$idx;
        $unlock->();
    }
    1;
}

sub remove {
    my $driver = shift;
    my($obj) = @_;
    my $id = $obj->id;
    return unless $id;
    my $indexes = $obj->properties->{indexes};
    for my $col (keys %$indexes) {
        my $idx_file = _db_index($driver, $obj, $col);
        my($DB, $idx, $unlock) =
            $driver->_tie_db_file($idx_file, $DB_BTREE, 'rw')
            or return $driver->error(MT->translate(
                "Tie '[_1]' failed: [_2]", $idx_file, "$!" ));
        my $col_value = $obj->$col();
        _drop_from_index($idx, $id, $col_value);
        undef $DB;
        untie %$idx;
        $unlock->();
    }
    my $db_file = _db_data($driver, $obj);
    my($DB, $db, $unlock) = $driver->_tie_db_file($db_file, $DB_BTREE, 'rw')
        or return $driver->error(MT->translate(
            "Tie '[_1]' failed: [_2]", $db_file, "$!" ));
    delete $db->{$obj->id};
    undef $DB;
    untie %$db;
    $unlock->();
    1;
}

sub remove_all {
    my $driver = shift;
    my($class) = @_;
    my $indexes = $class->properties->{indexes};
    for my $col (keys %$indexes) {
        my $idx_file = _db_index($driver, $class, $col);
        next unless -e $idx_file;
        unlink $idx_file or
            return $driver->error(MT->translate(
                "Unlink of '[_1]' failed: [_2]", $idx_file, "$!" ));
    }
    my $db_file = _db_data($driver, $class);
    if (-e $db_file) {
        unlink $db_file or
            return $driver->error(MT->translate(
                "Unlink of '[_1]' failed: [_2]", $db_file, "$!" ));
    }
    1;
}

sub _drop_from_index {
    my($idx, $obj_id, $col_val) = @_;
    $col_val = '' unless defined $col_val;
    return unless exists $idx->{$col_val};
    my $idx_val = $idx->{$col_val};
    $idx_val = '' unless defined $idx_val;
    my %ids = map { $_ => 1 } split /$;/, $idx_val;
    delete $ids{$obj_id};
    if (%ids) {
        $idx->{$col_val} = join $;, keys %ids;
    } else {
        delete $idx->{$col_val};
    }
}

sub generate_id {
    my $driver = shift;
    my($this) = @_;
    my $class = ref($this) || $this;
    my $id_file = File::Spec->catfile(
        $driver->cfg->DataSource, "ids.db");
    my($DB, $db, $unlock) = $driver->_tie_db_file($id_file, $DB_HASH, 'rw')
        or return $driver->error(MT->translate(
            "Tie '[_1]' failed: [_2]", $id_file, "$!" ));
    $db->{$class} = 0 unless exists $db->{$class};
    my $id = ++$db->{$class};
    undef $DB;
    untie %$db;
    $unlock->();
    $id;
}

1;
