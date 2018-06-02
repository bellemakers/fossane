# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: App.pm,v 1.90 2003/05/28 07:49:19 btrott Exp $

package MT::App;
use strict;

use File::Spec;

use MT::Log;
use MT::Request;
use MT::Util qw( encode_html offset_time_list decode_html );
use MT;
@MT::App::ISA = qw( MT );

use vars qw( %Global_actions );
sub add_methods {
    my $this = shift;
    my %meths = @_;
    if (ref($this)) {
        for my $meth (keys %meths) {
            $this->{vtbl}{$meth} = $meths{$meth};
        }
    } else {
        for my $meth (keys %meths) {
            $Global_actions{$this}{$meth} = $meths{$meth};
        }
    }
}

sub handler ($$) {
    my $class = shift;
    my($r) = @_;
    require Apache::Constants;
    if (lc($r->dir_config('Filter') || '') eq 'on') {
        $r = $r->filter_register;
    }
    my $config_file = $r->dir_config('MTConfig');
    my $app = $class->new( Config => $config_file, ApacheObject => $r )
        or die $class->errstr;
    my $cfg = $app->{cfg};
    my @extra = $r->dir_config('MTSetVar');
    for my $d (@extra) {
        my($var, $val) = $d =~ /^\s*(\S+)\s+(.+)$/;
        $cfg->set($var, $val);
    }
    $app->run;
    return Apache::Constants::OK();
}

sub send_http_header {
    my $app = shift;
    my($type) = @_;
    $type ||= 'text/html';
    if (my $charset = $app->{charset}) {
        $type .= "; charset=$charset"
            if $type =~ m!^text/! && $type !~ /\bcharset\b/;
    }
    if ($ENV{MOD_PERL}) {
        $app->{apache}->send_http_header($type);
    } else {
        $app->{cgi_headers}{-type} = $type;
        print $app->{query}->header(%{ $app->{cgi_headers} });
    }
}

sub print {
    my $app = shift;
    if ($ENV{MOD_PERL}) {
        $app->{apache}->print(@_);
    } else {
        CORE::print(@_);
    }
}

sub init {
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;
    $app->{vtbl} = { };
    $app->{requires_login} = 0;
    $app->{is_admin} = 0;
    $app->{template_dir} = '';
    $app->{cgi_headers} = { };
    if ($ENV{MOD_PERL}) {
        require Apache::Request;
        $app->{apache} = $param{ApacheObject} || Apache->request;
        $app->{query} = Apache::Request->new($app->{apache},
            POST_MAX => $app->{cfg}->CGIMaxUpload);
    } else {
        require CGI;
        $CGI::POST_MAX = $app->{cfg}->CGIMaxUpload;
        $app->{query} = CGI->new;
    }
    $app->{cookies} = $app->cookies;
    ## Initialize the MT::Request singleton for this particular request.
    MT::Request->instance;
    ## Load up the object's initial vtbl with any global methods.
    if (my $meths = $Global_actions{ref($app)}) {
        for my $meth (keys %$meths) {
            $app->{vtbl}{$meth} = $meths->{$meth};
        }
    }
    $app;
}

sub is_authorized { 1 }

sub login {
    my $app = shift;
    my $q = $app->{query};
    my $cookies = $app->{cookies};
    my($user, $pass, $remember, $crypted);
    my $first_time = 0;
    if ($cookies->{user}) {
        ($user, $pass, $remember) = split /::/, $cookies->{user}->value;
        $crypted = 1;
    } else {
        $first_time = 1;
        $user = $q->param('username');
        $pass = $q->param('password');
    }
    return unless $user && $pass;
    my $user_class = $app->{user_class};
    eval "use $user_class;";
    return $app->error("Error loading $user_class: $@") if $@;
    if (my $author = $user_class->load({ name => $user })) {
        if ($author->is_valid_password($pass, $crypted)) {
            if ($first_time) {
                $app->log("User '" . $author->name . "' logged in " .
                          "successfully");
            }
            return($author, $first_time);
        }
    }
    ## Login invalid, so get rid of cookie (if it exists) and let the
    ## user know.
    $app->log("Invalid login attempt from user '$user'");
    $app->bake_cookie(-name => 'user', -value => '', -expires => '-1y')
        unless $first_time;
    return $app->error("Invalid login.");
}

sub set_header {
    my $app = shift;
    my($key, $val) = @_;
    if ($ENV{MOD_PERL}) {
        $app->{apache}->header_out($key, $val);
    } else {
        unless ($key =~ /^-/) {
            ($key = lc($key)) =~ tr/-/_/;
            $key = '-' . $key;
        }
        $app->{cgi_headers}{$key} = $val;
    }
}

sub bake_cookie {
    my $app = shift;
    my %param = @_;
    unless ($param{-path}) {
        $param{-path} = $app->path;
    }
    if ($ENV{MOD_PERL}) {
        require Apache::Cookie;
        my $cookie = Apache::Cookie->new($app->{apache}, %param);
        $cookie->bake;
    } else {
        require CGI::Cookie;
        my $cookie = CGI::Cookie->new(%param);
        $app->set_header('-cookie', $cookie);
    }
}

sub cookies {
    my $app = shift;
    my $class = $ENV{MOD_PERL} ? 'Apache::Cookie' : 'CGI::Cookie';
    eval "use $class;";
    $class->fetch;
}

sub show_error {
    my $app = shift;
    my($error) = @_;
    my $tmpl;
    $error = encode_html($error);
    $error =~ s!(http://\S+)!<a href="$1" target="_blank">$1</a>!g;
    $tmpl = $app->load_tmpl('error.tmpl') or
        return "Can't load error template; got error '" . $app->errstr .
               "'. Giving up. Original error was <pre>$error</pre>";
    $tmpl->param(ERROR => $error);
    $tmpl->output;
}

sub pre_run { 1 }
sub post_run { 1 }

sub run {
    my $app = shift;
    my $q = $app->{query};
    my($body);
    eval {
        if ($ENV{MOD_PERL}) {
            my $status = $q->parse;
            unless ($status == Apache::Constants::OK()) {
                die $app->translate('The file you uploaded is too large.') .
                    "\n";
            }
        } else {
            my $err;
            eval { $err = $q->cgi_error };
            unless ($@) {
                if ($err && $err =~ /^413/) {
                    die $app->translate('The file you uploaded is too large.') .
                        "\n";
                }
            }
        }

        REQUEST:
        {
            if ($app->{requires_login}) {
            LOGIN:
            {
                my($author, $first_time) = $app->login;
                if ($author) {
                    $app->{author} = $app->{user} = $author;
                    if ($first_time) {
                        my $remember = $q->param('remember') ? 1 : 0;
                        my %arg = (
                            -name => 'user',
                            -value => join('::', $author->name, $author->password,
                                                 $remember),
                        );
                        $arg{-expires} = '+10y' if $remember;
                        $app->bake_cookie(%arg);
                    }
                    last LOGIN if $app->is_authorized;
                }
                $body = $app->build_page('login.tmpl', {error => $app->errstr})
                    or $body = $app->show_error( $app->errstr ), last REQUEST;
                last REQUEST;
            }  ## end LOGIN block
            }

            $app->pre_run;
            my $mode = $q->param('__mode') || $app->{default_mode};
            my $code = $app->{vtbl}{$mode} or
                $app->error($app->translate('Unknown action [_1]', $mode));
            if ($code) {
                $body = $code->($app);
            }
            $app->post_run;
            unless (defined $body || $app->{redirect}) {
                if ($app->{no_print_body}) {
                    $app->print($app->errstr);
                } else {
                    $body = $app->show_error( $app->errstr );
                }
            }
        }  ## end REQUEST block
    };
    if ($@) {
        $body = $app->show_error($@);
    }

    ## Add the Pragma: no-cache header.
    ## WEIRD: for CGI::cache, any true argument to cache means NO cache
    if ($ENV{MOD_PERL}) {
        $app->{apache}->no_cache(1);
    } else {
        $q->cache(1);
    }

    if (my $url = $app->{redirect}) {
        if ($ENV{MOD_PERL}) {
            $app->{apache}->header_out(Location => $url);
            $app->{apache}->status(Apache::Constants::REDIRECT());
            $app->send_http_header;
        } else {
            print $q->redirect(-uri => $url, %{ $app->{cgi_headers} });
        }
    } else {
        unless ($app->{no_print_body}) {
            $app->send_http_header;
            $app->print($body);
            $app->print("<pre>$app->{trace}</pre>") if $app->{trace};
        }
    }
}

sub l10n_filter { $_[0]->translate_templatized($_[1]) }

sub load_tmpl {
    my $app = shift;
    my($file, @p) = @_;
    my $path = $app->{cfg}->TemplatePath;
    require HTML::Template;
    my $tmpl;
    eval {
        $tmpl = HTML::Template->new_file(
            File::Spec->catfile($path, $app->{template_dir}, $file),
            path => [ File::Spec->catdir($path, $app->{template_dir}) ],
            die_on_bad_params => 0, global_vars => 1, @p);
    };
    my $err = $@;
    return $app->error(
        $app->translate("Loading template '[_1]' failed: [_2]", $file, $err))
        if $@;

    ## We do this in load_tmpl because show_error and login don't call
    ## build_page; so we need to set these variables here.
    my $spath = $app->{cfg}->StaticWebPath || $app->path;
    $spath .= '/' unless $spath =~ m!/$!;
    $tmpl->param(static_uri => $spath);
    $tmpl->param(script_url => $app->uri);
    $tmpl->param(script_path => $app->path);
    $tmpl->param(script_full_url => $app->base . $app->uri);
    $tmpl->param(mt_version => MT->VERSION);

    $tmpl->param(language_tag => $app->current_language);
    my $enc = $app->{cfg}->PublishCharset ||
              $app->language_handle->encoding;
    $tmpl->param(language_encoding => $enc);
    $app->{charset} = $enc;

    $tmpl;
}

sub build_page {
    my $app = shift;
    my($file, $param) = @_;
    my $tmpl = $app->load_tmpl($file) or return;
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    $app->l10n_filter($tmpl->output);
}

sub delete_param {
    my $app = shift;
    my($key) = @_;
    my $q = $app->{query};
    if ($ENV{MOD_PERL}) {
        my $tab = $q->parms;
        $tab->unset($key);
    } else {
        $q->delete($key);
    }
}

## Path/server/script-name determination methods

sub base {
    my $app = shift;
    return $app->{__host} if exists $app->{__host};
    my $path = $app->{is_admin} ?
        ($app->{cfg}->AdminCGIPath || $app->{cfg}->CGIPath) :
        $app->{cfg}->CGIPath;
    if ($path =~ m!^(https?://[^/]+)!i) {
        (my $host = $1) =~ s!/$!!;
        return $app->{__host} = $host;
    }
    '';
}

sub path {
    my $app = shift;
    return $app->{__path} if exists $app->{__path};
    my $path = $app->{is_admin} ?
        ($app->{cfg}->AdminCGIPath || $app->{cfg}->CGIPath) :
        $app->{cfg}->CGIPath;
    if ($path =~ m!^https?://[^/]+(/.*)$!i) {
        $path = $1;
    } elsif (!$path) {
        $path = '/';
    }
    $path .= '/' unless substr($path, -1, 1) eq '/';
    $app->{__path} = $path;
}

sub script {
    my $app = shift;
    return $app->{__script} if exists $app->{__script};
    my $script = $ENV{MOD_PERL} ? $app->{apache}->uri : $ENV{SCRIPT_NAME};
    $script =~ s!/$!!;
    $script = (split /\//, $script)[-1];
    $app->{__script} = $script;
}

sub uri { $_[0]->path . $_[0]->script }

sub path_info {
    my $app = shift;
    return $app->{__path_info} if exists $app->{__path_info};
    my $path_info;
    if ($ENV{MOD_PERL}) {
        ## mod_perl often leaves part of the script name (Location)
        ## in the path info, for some reason. This should remove it.
        $path_info = $app->{apache}->path_info;
        if ($path_info) {
            my($script_last) = $app->{apache}->location =~ m!/([^/]+)$!;
            $path_info =~ s!^/$script_last!!;
        }
    } else {
        $path_info = $app->{query}->path_info;
    }
    $app->{__path_info} = $path_info;
}

sub redirect {
    my $app = shift;
    my($url) = @_;
    unless ($url =~ m!^https?://!i) {
        $url = $app->base . $url;
    }
    $app->{redirect} = $url;
    return;
}

## Logging/tracing

sub log {
    my $app = shift;
    my($msg) = @_;
    my $log = MT::Log->new;
    $log->message($msg);
    $log->ip($app->remote_ip);
    $log->save;
}

sub trace { $_[0]->{trace} .= "@_" }

sub remote_ip {
    my $app = shift;
    $ENV{MOD_PERL} ? $app->{apache}->connection->remote_ip : $ENV{REMOTE_ADDR};
}

sub DESTROY {
    ## Destroy the Request object, which is used for caching
    ## per-request data. We have to do this manually, because in
    ## a persistent environment, the object will not go out of scope.
    ## Same with the ConfigMgr object and ObjectDriver.
    undef $MT::Request::r;
    undef $MT::Object::DRIVER;
    undef $MT::ConfigMgr::cfg;
}

1;
__END__

=head1 NAME

MT::App - Movable Type base web application class

=head1 SYNOPSIS

    package MT::App::Foo;
    use MT::App;
    @MT::App::Foo::ISA = qw( MT::App );

    package main;
    my $app = MT::App::Foo->new;
    $app->run;

=head1 DESCRIPTION

I<MT::App> is the base class for Movable Type web applications. It provides
support for an application running using standard CGI, or under
I<Apache::Registry>, or as a I<mod_perl> handler. I<MT::App> is not meant to
be used directly, but rather as a base class for other web applications using
the Movable Type framework (for example, I<MT::App::CMS>).

=head1 USAGE

I<MT::App> subclasses the I<MT> class, which provides it access to the
publishing methods in that class.

Following are the list of methods specific to I<MT::App>:

=head2 MT::App->new

Constructs and returns a new I<MT::App> object.

=head2 $app->run

Runs the application. This gathers the input, chooses the method to execute,
executes it, and prints the output to the client.

If an error occurs during the execution of the application, I<run> handles all
of the errors thrown either through the I<MT::ErrorHandler> or through I<die>.

=head2 $app->login

Checks the user's credentials, first by looking for a login cookie, then by
looking for the C<username> and C<password> CGI parameters. In both cases,
the username and password are verified for validity. This method does not set
the user's login cookie, however--that should be done by the caller (in most
cases, the caller is the I<run> method).

On success, returns the I<MT::Author> object representing the author who logged
in, and a boolean flag; if the boolean flag is true, it indicates the the login
credentials were obtained from the CGI parameters, and thus that a cookie
should be set by the caller. If the flag is false, the credentials came from
an existing cookie.

On an authentication error, I<login> removes any authentication cookies that
the user might have on his or her browser, then returns C<undef>, and the
error message can be obtained from C<$app-E<gt>errstr>.

=head2 $app->send_http_header([ $content_type ])

Sends the HTTP header to the client; if I<$content_type> is specified, the
I<Content-Type> header is set to I<$content_type>. Otherwise, C<text/html> is
used as the default.

In a I<mod_perl> context, this calls the I<Apache::send_http_header> method;
in a CGI context, the I<CGI::header> method is called.

=head2 $app->print(@data)

Sends data I<@data> to the client.

In a I<mod_perl> context, this calls the I<Apache::print> method; in a CGI
context, data is printed directly to STDOUT.

=head2 $app->bake_cookie(%arg)

Bakes a cookie to be sent to the client.

I<%arg> can contain any valid parameters to the I<new> methods of
I<CGI::Cookie> (or I<Apache::Cookie>--both take the same parameters). These
include C<-name>, C<-value>, C<-path>, and C<-expires>.

If you do not include the C<-path> parameter in I<%arg>, it will be set
automatically to C<$app-E<gt>path> (below).

In a I<mod_perl> context, this method uses I<Apache::Cookie>; in a CGI context,
it uses I<CGI::Cookie>.

=head2 $app->cookies

Returns a reference to a hash containing cookie objects, where the objects are
either of class I<Apache::Cookie> (in a I<mod_perl> context) or I<CGI::Cookie>
(in a CGI context).

=head2 $app->build_page($tmpl_name, \%param)

Builds an application page to be sent to the client; the page name is specified
in I<$tmpl_name>, which should be the name of a template containing valid
I<HTML::Template> markup. I<\%param> is a hash ref whose keys and values will
be passed to I<HTML::Template::param> for use in the template.

On success, returns a scalar containing the page to be sent to the client. On
failure, returns C<undef>, and the error message can be obtained from
C<$app-E<gt>errstr>.

=head2 $app->redirect($url)

Issues a redirect to the client to the URL I<$url>. If I<$url> is not an
absolute URL, it is prepended with the value of I<$app-E<gt>base>.

=head2 $app->base

The protocol and domain of the application. For example, with the full URI
F<http://www.foo.com/mt/mt.cgi>, this method will return F<http://www.foo.com>.

=head2 $app->path

The path to the application directory. For example, with the full URI
F<http://www.foo.com/mt/mt.cgi>, this method will return F</mt/>.

=head2 $app->script

The name of the application. For example, with the full URI
F<http://www.foo.com/mt/mt.cgi>, this method will return F<mt.cgi>.

=head2 $app->uri

The concatenation of C<$app-E<gt>path> and C<$app-E<gt>script>. For example,
with the full URI F<http://www.foo.com/mt/mt.cgi>, this method will return
F</mt/mt.cgi>.

=head2 $app->path_info

The path_info for the request (that is, whatever is left in the URI after the
URI to filename translation).

=head2 $app->log($msg)

Adds the message I<$msg> to the activity log. The log entry will be tagged
with the IP address of the client running the application (that is, of the
browser that made the HTTP request), using C<$app-E<gt>remote_ip>.

=head2 $app->trace(@msg)

Adds a trace message "I<@msg>" to the internal tracing mechanism; trace
messages are then displayed at the top of the output page sent to the client.
This is useful for debugging.

=head2 $app->remote_ip

The IP address of the client.

In a I<mod_perl> context, this calls I<Apache::Connection::remote_ip>; in a
CGI context, this uses I<$ENV{REMOTE_ADDR}>.

=head1 AUTHOR & COPYRIGHTS

Please see the I<MT> manpage for author, copyright, and license information.

=cut
