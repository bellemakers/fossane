# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: Mail.pm,v 1.14 2003/02/12 00:15:03 btrott Exp $

package MT::Mail;
use strict;

use MT;
use MT::ConfigMgr;
use MT::ErrorHandler;
@MT::Mail::ISA = qw( MT::ErrorHandler );

sub send {
    my $class = shift;
    my($hdrs, $body) = @_;
    $body .= <<SIG;

-- 
@{[ MT->version_slug ]}
SIG
    my $mgr = MT::ConfigMgr->instance;
    my $xfer = $mgr->MailTransfer;
    if ($xfer eq 'sendmail') {
        return $class->_send_mt_sendmail($hdrs, $body, $mgr);
    } elsif ($xfer eq 'smtp') {
        return $class->_send_mt_smtp($hdrs, $body, $mgr);
    } elsif ($xfer eq 'debug') {
        return $class->_send_mt_debug($hdrs, $body, $mgr);
    } else {
        return $class->error(MT->translate(
            "Unknown MailTransfer method '[_1]'", $xfer ));
    }
}

sub _send_mt_debug {
    my $class = shift;
    my($hdrs, $body, $mgr) = @_;
    for my $key (keys %$hdrs) {
        my @arr = ref($hdrs->{$key}) eq 'ARRAY' ?
            @{ $hdrs->{$key} } : ($hdrs->{$key});
        print STDERR map "$key: $_\n", @arr;
    }
    print STDERR "\n";
    print STDERR $body;
    1;
}

sub _send_mt_smtp {
    my $class = shift;
    my($hdrs, $body, $mgr) = @_;
    eval { require Mail::Sendmail; };
    return $class->error(MT->translate(
        "Sending mail via SMTP requires that your server " .
        "have Mail::Sendmail installed: [_1]", $@ )) if $@;
    my %hdrs = %$hdrs;
    $hdrs{Message} = $body;
    $hdrs{Smtp} = $mgr->SMTPServer;
    for my $h (qw( Cc Bcc )) {
        if ($hdrs{$h}) {
            $hdrs{$h} = join ', ', @{ $hdrs{$h} };
        }
    }
    my $ret = Mail::Sendmail::sendmail(%hdrs);
    $ret or return $class->error(MT->translate(
        "Error sending mail: [_1]", $Mail::Sendmail::error ));
    1;
}

my @Sendmail = qw( /usr/lib/sendmail /usr/sbin/sendmail /usr/ucblib/sendmail );
sub _send_mt_sendmail {
    my $class = shift;
    my($hdrs, $body, $mgr) = @_;
    my $sm_loc;
    for my $loc ($mgr->SendMailPath, @Sendmail) {
        next unless $loc;
        $sm_loc = $loc, last if -x $loc && !-d $loc;
    }
    return $class->error(MT->translate(
        "You do not have a valid path to sendmail on your machine. " .
        "Perhaps you should try using SMTP?" ))
        unless $sm_loc;
    local $SIG{PIPE} = { };
    my $pid = open MAIL, '|-';
    local $SIG{ALRM} = sub { CORE::exit() };
    return unless defined $pid;
    if (!$pid) {
        exec $sm_loc, "-t" or
            return $class->error(MT->translate(
                "Exec of sendmail failed: [_1]", "$!" ));
    }
    for my $key (keys %$hdrs) {
        my @arr = ref($hdrs->{$key}) eq 'ARRAY' ?
            @{ $hdrs->{$key} } : ($hdrs->{$key});
        print MAIL map "$key: $_\n", @arr;
    }
    print MAIL "\n";
    print MAIL $body;
    close MAIL;
    1;
}

1;
__END__

=head1 NAME

MT::Mail - Movable Type mail sender

=head1 SYNOPSIS

    use MT::Mail;
    my %head = ( To => 'foo@bar.com', Subject => 'My Subject' );
    my $body = 'This is the body of the message.';
    MT::Mail->send(\%head, $body)
        or die MT::Mail->errstr;

=head1 DESCRIPTION

I<MT::Mail> is the Movable Type mail-sending interface. It can send mail
through I<sendmail> (in several different default locations), through SMTP,
or through a debugging interface that writes data to STDERR. You can set the
method of sending mail through the F<mt.cfg> file by changing the value for
the I<MailTransfer> setting to one of the following values: C<sendmail>,
C<smtp>, or C<debug>.

If you are using C<sendmail>, I<MT::Mail::send> looks for your I<sendmail>
program in any of the following locations: F</usr/lib/sendmail>,
F</usr/sbin/sendmail>, and F</usr/ucblib/sendmail>. If your I<sendmail> is at
a different location, you can set it using the I<SendMailPath> directive.

If you are using C<smtp>, I<MT::Mail::send> will by default use C<localhost>
as the SMTP server. You can change this by setting the I<SMTPServer>
directive.

=head1 USAGE

=head2 MT::Mail->send(\%headers, $body)

Sends a mail message with the headers I<\%headers> and the message body
I<$body>.

The keys and values in I<\%headers> are passed directly in to the mail
program or server, so you can use any valid mail header names as keys. If
you need to supply a list of header values, specify the hash value as a
reference to a list of the header values. For example:

    %headers = ( Bcc => [ 'foo@bar.com', 'baz@quux.com' ] );

If you wish the lines in I<$body> to be wrapped, you should do this yourself;
it will not be done by I<send>.

On success, I<send> returns true; on failure, it returns C<undef>, and the
error message is in C<MT::Mail-E<gt>errstr>.

=head1 AUTHOR & COPYRIGHT

Please see the I<MT> manpage for author, copyright, and license information.

=cut
