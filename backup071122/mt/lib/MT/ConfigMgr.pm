# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: ConfigMgr.pm,v 1.66 2003/03/07 00:03:02 btrott Exp $

package MT::ConfigMgr;
use strict;

use MT::ErrorHandler;
@MT::ConfigMgr::ISA = qw( MT::ErrorHandler );

use vars qw( $cfg );
sub instance {
    return $cfg if $cfg;
    $cfg = __PACKAGE__->new;
}

sub new {
    my $mgr = bless { __var => { } }, $_[0];
    $mgr->init;
    $mgr;
}

sub init {
    my $mgr = shift;
    $mgr->define('DataSource', Default => './db');
    $mgr->define('Database');
    $mgr->define('DBHost');
    $mgr->define('DBSocket');
    $mgr->define('DBPort');
    $mgr->define('DBUser');
    $mgr->define('DBPassword');
    $mgr->define('DefaultLanguage', Default => 'en_us');
    $mgr->define('TemplatePath');
    $mgr->define('ImportPath');
    $mgr->define('PluginPath');
    $mgr->define('SearchTemplatePath');
    $mgr->define('ObjectDriver', Default => 'DBM');
    $mgr->define('Serializer', Default => 'MT');
    $mgr->define('SendMailPath', Default => '/usr/lib/sendmail');
    $mgr->define('TimeOffset', Default => 0);
    $mgr->define('StaticWebPath', Default => '');
    $mgr->define('CGIPath', Default => '/cgi-bin/');
    $mgr->define('AdminCGIPath');
    $mgr->define('MailTransfer', Default => 'sendmail');
    $mgr->define('SMTPServer', Default => 'localhost');
    $mgr->define('WeblogsPingURL', Default => 'http://rpc.weblogs.com/RPC2');
    $mgr->define('BlogsPingURL', Default => 'http://ping.blo.gs/');
    $mgr->define('MTPingURL', Default => 'http://www.movabletype.org/update/');
    $mgr->define('CGIMaxUpload', Default => 1_000_000);
    $mgr->define('DBUmask', Default => '0111');
    $mgr->define('HTMLUmask', Default => '0111');
    $mgr->define('UploadUmask', Default => '0111');
    $mgr->define('DirUmask', Default => '0000');
    $mgr->define('HTMLPerms', Default => '0666');
    $mgr->define('UploadPerms', Default => '0666');
    $mgr->define('NoTempFiles', Default => 0);
    $mgr->define('TempDir', Default => '/tmp');
    $mgr->define('EntriesPerRebuild', Default => 40);
    $mgr->define('UseNFSSafeLocking', Default => 0);
    $mgr->define('NoLocking', Default => 0);
    $mgr->define('NoHTMLEntities', Default => 0);
    $mgr->define('NoCDATA', Default => 0);
    $mgr->define('NoPlacementCache', Default => 0);
    $mgr->define('NoPublishMeansDraft', Default => 0);
    $mgr->define('PingTimeout', Default => 15);
    $mgr->define('PingInterface');
    $mgr->define('PingProxy');
    $mgr->define('PingNoProxy', Default => 'localhost, 127.0.0.1');
    $mgr->define('ImageDriver', Default => 'ImageMagick');
    $mgr->define('NetPBMPath');
    $mgr->define('CommentScript', Default => 'mt-comments.cgi');
    $mgr->define('TrackbackScript', Default => 'mt-tb.cgi');
    $mgr->define('SearchScript', Default => 'mt-search.cgi');
    $mgr->define('XMLRPCScript', Default => 'mt-xmlrpc.cgi');
    $mgr->define('ViewScript', Default => 'mt-view.cgi');
    $mgr->define('PublishCharset');
    $mgr->define('SafeMode', Default => 1);
    $mgr->define('GlobalSanitizeSpec', Default => 'a href,b,i,br/,p,strong,em,ul,ol,li,blockquote,pre');
    $mgr->define('GenerateTrackBackRSS', Default => 1);

    ## Search settings, copied from Jay's mt-search and integrated
    ## into default config.
    $mgr->define('NoOverride', Default => '');
    $mgr->define('RegexSearch', Default => 0);
    $mgr->define('CaseSearch', Default => 0);
    $mgr->define('ResultDisplay', Default => 'descend');
    $mgr->define('ExcerptWords', Default => 40);
    $mgr->define('SearchElement', Default => 'entries');
    $mgr->define('ExcludeBlogs');
    $mgr->define('IncludeBlogs');
    $mgr->define('DefaultTemplate', Default => 'default.tmpl');
    $mgr->define('Type', Default => 'straight');
    $mgr->define('MaxResults', Default => '9999999');
    $mgr->define('SearchCutoff', Default => '9999999');
    $mgr->define('CommentSearchCutoff', Default => '30');
    $mgr->define('AltTemplate', Multiple => 1);
    $mgr->define('SearchSortBy');
    $mgr->define('SearchSortOrder', Default => 'ascend');
}

sub define {
    my $mgr = shift;
    my($var, %param) = @_;
    $mgr->{__var}{$var} = undef;
    $mgr->{__settings}{$var} = keys %param ? \%param : {};
    if (exists $param{Default}) {
        $mgr->{__var}{$var} = $param{Default};
    }
}

sub get { $_[0]->{__var}{ $_[1] } }
sub set {
    my $mgr = shift;
    my($var, $val) = @_;
    if ($mgr->{__settings}{$var}{Multiple}) {
        push @{ $mgr->{__var}{$var} }, $val;
    } else {
        $mgr->{__var}{$var} = $val;
    }
}

sub read_config {
    my $class = shift;
    my($cfg_file) = @_;
    my $mgr = $class->instance;
    local(*FH, $_, $/);
    $/ = "\n";
    open FH, $cfg_file or
        return $class->error(MT->translate(
            "Error opening file '[_1]': [_2]", $cfg_file, "$!" ));
    while (<FH>) {
        chomp;
        next if !/\S/ || /^#/;
        my($var, $val) = $_ =~ /^\s*(\S+)\s+(.+)$/;
        $val =~ s/\s*$//;
        next unless $var && defined($val);
        return $class->error(MT->translate(
            "[_1]:[_2]: variable '[_3]' not defined", $cfg_file, $., $var
            )) unless exists $mgr->{__var}->{$var};
        $mgr->set($var, $val);
    }
    close FH;
    1;
}

sub DESTROY { }

use vars qw( $AUTOLOAD );
sub AUTOLOAD {
    my $mgr = $_[0];
    (my $var = $AUTOLOAD) =~ s!.+::!!;
    return $mgr->error(MT->translate("No such config variable '[_1]'", $var))
        unless exists $mgr->{__var}->{$var};
    no strict 'refs';
    *$AUTOLOAD = sub {
        my $mgr = shift;
        @_ ? $mgr->set($var, $_[0]) : $mgr->get($var);
    };
    goto &$AUTOLOAD;
}

1;
__END__

=head1 NAME

MT::ConfigMgr - Movable Type configuration manager

=head1 SYNOPSIS

    use MT::ConfigMgr;
    my $cfg = MT::ConfigMgr->instance;

    $cfg->read_config('/path/to/mt.cfg')
        or die $cfg->errstr;

=head1 DESCRIPTION

I<MT::ConfigMgr> is a singleton class that manages the Movable Type
configuration file (F<mt.cfg>), allowing access to the config directives
contained therin.

=head1 USAGE

=head2 MT::ConfigMgr->instance

Returns the singleton I<MT::ConfigMgr> object. Note that when you want the
object, you should always call I<instance>, never I<new>; I<new> will construct
a B<new> I<MT::ConfigMgr> object, and that isn't what you want. You want the
object that has already been initialized with the contents of F<mt.cfg>. This
initialization is done by I<MT::new>.

=head2 $cfg->read_config($file)

Reads the config file at the path I<$file> and initializes the I<$cfg> object
with the directives in that file. Returns true on success, C<undef> otherwise;
if an error occurs you can obtain the error message with C<$cfg-E<gt>errstr>.

=head2 $cfg->define($directive [, %arg ])

Defines the directive I<$directive> as a valid configuration directive; you
must define new configuration directives B<before> you read the configuration
file, or else the read will fail.

=head1 CONFIGURATION DIRECTIVES

The following configuration directives are allowed in F<mt.cfg>. To get the
value of a directive, treat it as a method that you are calling on the
I<$cfg> object. For example:

    $cfg->CGIPath

To set the value of a directive, do the same as the above, but pass in a value
to the method:

    $cfg->CGIPath('http://www.foo.com/mt/');

A list of valid configuration directives can be found in the
I<CONFIGURATION SETTINGS> section of the manual.

=head1 AUTHOR & COPYRIGHT

Please see the I<MT> manpage for author, copyright, and license information.

=cut
