# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Serialize.pm,v 1.10 2003/02/12 00:15:03 btrott Exp $

package MT::Serialize;
use strict;

{
    my %Types = (
        Storable => [ \&_freeze_storable, \&_thaw_storable ],
        MT       => [ \&_freeze_mt,       \&_thaw_mt    ],
    );

    sub new {
        my $class = shift;
        my $type = $Types{$_[0]};
        bless { freeze => $type->[0], thaw => $type->[1] }, $class;
    }
}

sub serialize {
    my $ser = shift;
    $ser->{freeze}->(@_);
}

sub unserialize {
    my $ser = shift;
    $ser->{thaw}->(@_);
}

sub _freeze_storable { require Storable; Storable::freeze(@_) }
sub _thaw_storable   { require Storable; Storable::thaw(@_)   }

sub _freeze_mt {
    my($ref) = @_;
    my $frozen = 'SERG';
    for my $col (keys %{ $$ref }) {
        my $col_val = ${$ref}->{$col};
        $col_val = '' unless defined $col_val;
        $frozen .= pack('N', length($col)) . $col .
                   pack('N', length($col_val)) . $col_val;
    }
    $frozen;
}

sub _thaw_mt {
    my($frozen) = @_;
    return unless substr($frozen, 0, 4) eq 'SERG';
    substr($frozen, 0, 4) = '';
    my $thawed = {};
    my $len = length $frozen;
    my $pos = 0;
    while ($pos < $len) {
        my $slen = unpack 'N', substr($frozen, $pos, 4);
        my $col = $slen ? substr($frozen, $pos+4, $slen) : '';
        $pos += 4 + $slen;
        $slen = unpack 'N', substr($frozen, $pos, 4);
        my $col_val = substr($frozen, $pos+4, $slen);
        $pos += 4 + $slen;
        $thawed->{$col} = $col_val;
    }
    \$thawed;
}

1;
