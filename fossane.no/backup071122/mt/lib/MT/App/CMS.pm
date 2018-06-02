# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: CMS.pm,v 1.288 2003/03/26 23:24:19 btrott Exp $

package MT::App::CMS;
use strict;

use Symbol;
use File::Spec;
use MT::Util qw( encode_html format_ts offset_time_list
                 remove_html get_entry );
use MT::App;
@MT::App::CMS::ISA = qw( MT::App );

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
            'menu' => \&show_menu,
            'save' => \&save_object,
            'view' => \&edit_object,
            'list' => \&list_objects,
            'list_entries' => \&list_entries,
            'save_entries' => \&save_entries,
            'save_entry' => \&save_entry,
            'cfg_archives' => \&cfg_archives,
            'cfg_prefs' => \&cfg_prefs,
            'cfg_archives_save' => \&cfg_archives_save,
	    'cfg_archives_add' => \&cfg_archives_add,
            'cfg_archives_do_add' => \&cfg_archives_do_add,
            'list_blogs' => \&list_blogs,
            'list_cat' => \&list_categories,
            'save_cat' => \&save_categories,
            'edit_placements' => \&edit_placements,
            'save_placements' => \&save_placements,
            'delete_confirm' => \&delete_confirm,
            'delete' => \&delete,
            'edit_permissions' => \&edit_permissions,
            'save_permissions' => \&save_permissions,
            'ping' => \&send_pings,
            'rebuild' => \&rebuild_pages,
            'start_rebuild' => \&start_rebuild_pages,
            'rebuild_confirm' => \&rebuild_confirm,
            'send_notify' => \&send_notify,
            'start_upload' => \&start_upload,
            'upload_file' => \&upload_file,
            'start_upload_entry' => \&start_upload_entry,
            'show_upload_html' => \&show_upload_html,
            'logout' => \&logout,
            'start_recover' => \&start_recover,
            'recover' => \&recover_password,
            'bookmarklets' => \&bookmarklets,
            'make_bm_link' => \&make_bm_link,
            'view_log' => \&view_log,
            'reset_log' => \&reset_log,
            'start_import' => \&start_import,
            'search_replace' => \&search_replace,
            'start_search_replace' => \&start_search_replace,
            'export' => \&export,
            'import' => \&do_import,
            'pinged_urls' => \&pinged_urls,
            'tb_cat_pings' => \&tb_cat_pings,
            'show_entry_prefs' => \&show_entry_prefs,
            'save_entry_prefs' => \&save_entry_prefs,
            'reg_file' => \&reg_file,
            'reg_bm_js' => \&reg_bm_js,
            'category_add' => \&category_add,
            'category_do_add' => \&category_do_add,
            'cc_return' => \&cc_return,
    );
    $app->{default_mode} = 'list_blogs';
    $app->{template_dir} = 'cms';
    my $mode = $app->{query}->param('__mode');
    $app->{requires_login} =
        $mode && ($mode eq 'start_recover' || $mode eq 'recover') ?
        0 : 1;
    $app->{is_admin} = 1;
    $app->{user_class} = 'MT::Author';
    $app;
}

sub pre_run {
    my $app = shift;
    my $auth = $app->{author};
    $app->set_language($auth->preferred_language)
        if $auth && $auth->preferred_language;
    ## Localize the label of the default text filter.
    $MT::Text_filters{__default__}{label} =
        $app->translate('Convert Line Breaks');
    1;
}

sub logout {
    my $app = shift;
    $app->log("User '" . $app->{author}->name . "' logged out");
    delete $app->{author};
    $app->bake_cookie(-name => 'user', -value => '', -expires => '-1y');
    $app->build_page('login.tmpl', { logged_out => 1 });
}

sub start_recover {
    my $app = shift;
    $app->build_page('recover.tmpl');
}

sub recover_password {
    my $app = shift;
    my $q = $app->{query};
    require MT::Author;
    my $name = $q->param('name');
    my $author = MT::Author->load({ name => $name });
    $app->log("Invalid author name '$name' in password recovery attempt"),
        return $app->error($app->translate(
            "No such author with name '[_1]'", $name)) unless $author;
    return $app->error($app->translate(
        "Author has not set birthplace; cannot recover password"))
        unless $author->hint;
    my $hint = $q->param('hint');
    $app->log("Invalid attempt to recover password (used birthplace '$hint')"),
    return $app->error($app->translate(
        "Birthplace '[_1]' does not match stored birthplace " .
        "for this author", $hint)) unless $author->hint eq $hint;
    return $app->error($app->translate("Author does not have email address"))
        unless $author->email;
    my @pool = ('a'..'z', 0..9);
    my $pass;
    for (1..8) { $pass .= $pool[ rand @pool ] }
    $author->set_password($pass);
    $author->save;
    my %head = ( To => $author->email, From => $author->email,
                 Subject => "Password Recovery" );
    my $body = $app->translate('_USAGE_FORGOT_PASSWORD_1') .
               "\n\n    $pass\n\n" .
               $app->translate('_USAGE_FORGOT_PASSWORD_2') . "\n";
    require Text::Wrap;
    $Text::Wrap::columns = 72;
    $body = Text::Wrap::wrap('', '', $body);
    require MT::Mail;
    MT::Mail->send(\%head, $body) or
        return $app->error($app->translate(
            "Error sending mail ([_1]); please fix the problem, then " .
            "try again to recover your password.", MT::Mail->errstr));
    $app->build_page('recover.tmpl', { recovered => 1,
                                       email => $author->email });
}

sub is_authorized {
    my $app = shift;
    require MT::Permission;
    my $blog_id = $app->{query}->param('blog_id');
    return 1 unless $blog_id;
    return unless my $author = $app->{author};
    my $perms = $app->{perms} = MT::Permission->load({
        author_id => $author->id,
        blog_id => $blog_id });
    $perms ? 1 :
        $app->error($app->translate(
            "You are not authorized to log in to this blog."));
}

sub build_page {
    my $app = shift;
    my($page, $param) = @_;
    if (my $perms = $app->{perms}) {
        $param->{can_post} = $perms->can_post;
        $param->{can_upload} = $perms->can_upload;
        $param->{can_edit_entries} =
            $perms->can_post || $perms->can_edit_all_posts;
        $param->{can_search_replace} = $perms->can_edit_all_posts;
        $param->{can_edit_templates} = $perms->can_edit_templates;
        $param->{can_edit_authors} = $perms->can_edit_authors;
        $param->{can_edit_config} = $perms->can_edit_config;
        $param->{can_rebuild} = $perms->can_rebuild;
        $param->{can_edit_categories} = $perms->can_edit_categories;
        $param->{can_edit_notifications} = $perms->can_edit_notifications;
        $param->{has_manage_label} =
            $perms->can_edit_templates  || $perms->can_edit_authors ||
            $perms->can_edit_categories || $perms->can_edit_config;
    }
    my $blog_id = $app->{query}->param('blog_id');
    if (my $auth = $app->{author}) {
        $param->{author_id} = $auth->id;
        $param->{author_name} = $auth->name;
        my @perms = MT::Permission->load({ author_id => $auth->id });
        my @data;
        for my $perms (@perms) {
            next unless $perms->role_mask;
            my $blog = MT::Blog->load($perms->blog_id);
            push @data, { top_blog_id => $blog->id,
                          top_blog_name => $blog->name };
            $data[-1]{top_blog_selected} = 1
                if $blog_id && $blog->id == $blog_id;
        }
        @data = sort { $a->{top_blog_name} cmp $b->{top_blog_name} } @data;
        $param->{top_blog_loop} = \@data;
    }
    if ($blog_id) {
        my $blog = MT::Blog->load($blog_id);
        $param->{blog_name} = $blog->name;
        $param->{blog_id} = $blog->id;
        $param->{blog_url} = $blog->site_url;
    }
    if ($app->{query}->param('is_bm')) {
        $param->{is_bookmarklet} = 1;
        if ($page eq 'login.tmpl') {
            ## For bookmarklets, we need to pass-thru text, title, and
            ## href vars
            my $q = $app->{query};
            $param->{text} = $q->param('text');
            $param->{link_title} = $q->param('link_title');
            $param->{link_href} = $q->param('link_href');
            $param->{bm_show} = $q->param('bm_show');
        } 
    }
    $param->{agent_mozilla} = $ENV{HTTP_USER_AGENT} =~ /gecko/i;
    $param->{have_tangent} = eval { require MT::Tangent; 1 } ? 1 : 0;
    $app->SUPER::build_page($page, $param);
}

## Application methods

sub show_menu {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    require MT::Comment;
    require MT::TBPing;
    require MT::Trackback;
    require MT::Permission;
    require MT::Entry;
    my $blog_id = $app->{query}->param('blog_id');
    my $iter = MT::Entry->load_iter({ blog_id => $blog_id },
        { 'sort' => 'created_on',
          direction => 'descend',
          limit => 5 });
    my @e_data;
    my $i = 1;
    my $author_id = $app->{author}->id;
    while (my $entry = $iter->()) {
        my $row = { entry_id => $entry->id,
                    entry_blog_id => $entry->blog_id, };
        unless ($row->{entry_title} = $entry->title) {
            my $title = remove_html($entry->text);
            $row->{entry_title} = substr($title, 0, 22) . '...';
        }
        $row->{entry_title} = encode_html($row->{entry_title}, 1);
        $row->{entry_created_on} = format_ts("%Y.%m.%d", $entry->created_on);
        $row->{is_odd} = $i++ % 2;
        $row->{has_edit_access} = $perms->can_edit_all_posts ||
            $entry->author_id == $author_id;
        push @e_data, $row;
    }
    $iter = MT::Comment->load_iter({ blog_id => $blog_id },
        { 'sort' => 'created_on',
          direction => 'descend',
          limit => 5 });
    my @c_data;
    $i = 1;
    while (my $comment = $iter->()) {
        my $row = { comment_id => $comment->id,
                    comment_author => $comment->author || '[No author]',
                    comment_blog_id => $comment->blog_id, };
        $row->{comment_created_on} = format_ts("%Y.%m.%d",
            $comment->created_on);
        my $entry = MT::Entry->load($comment->entry_id);
        $row->{has_edit_access} = $perms->can_edit_all_posts ||
            $entry->author_id == $author_id;
        $row->{is_odd} = $i++ % 2;
        push @c_data, $row;
    }
    $iter = MT::TBPing->load_iter({ blog_id => $blog_id },
        { 'sort' => 'created_on',
          direction => 'descend',
          limit => 5 });
    my @p_data;
    $i = 1;
    while (my $ping = $iter->()) {
        my $row = { ping_id => $ping->id,
                    ping_title => $ping->title || '[No title]',
                    ping_url => $ping->source_url,
                    ping_blog_id => $ping->blog_id, };
        $row->{ping_created_on} = format_ts("%Y.%m.%d", $ping->created_on);
        #my $tb = MT::Trackback->load($ping->tb_id);
        #my $entry = MT::Entry->load($tb->entry_id);
        #$row->{has_edit_access} = $perms->can_edit_all_posts ||
        #    $entry->author_id == $author_id;
        #$row->{ping_entry_id} = $entry->id;
        $row->{is_odd} = $i++ % 2;
        push @p_data, $row;
    }
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    my %param = (entry_loop => \@e_data, comment_loop => \@c_data,
                 ping_loop => \@p_data);
    $param{blog_description} = $blog->description;
    $param{welcome} = $blog->welcome_msg;
    $param{num_entries} = MT::Entry->count({ blog_id => $blog_id });
    $param{num_comments} = MT::Comment->count({ blog_id => $blog_id });
    $param{num_authors} = 0;
    $iter = MT::Permission->load_iter({ blog_id => $blog_id });
    while (my $p = $iter->()) {
        $param{num_authors}++ if $p->role_mask > 0;
    }
    $app->build_page('menu.tmpl', \%param);
}

sub bookmarklets { $_[0]->build_page('bookmarklets.tmpl') }
sub make_bm_link {
    my $app = shift;
    my %param = ( have_link => 1 );
    my @show = $app->{query}->param('show');
    my $height = 440;
    my %show = map { $_ => 1 } @show;
    $height += 50 if $show{trackback};
    $height += 40 if $show{allow_comments};
    $height += 20 if $show{allow_pings};
    $height += 40 if $show{convert_breaks};
    $height += 50 if $show{category};
    $height += 80 if $show{excerpt};
    $height += 80 if $show{keywords};
    $height += 80 if $show{text_more};
    $param{bm_show} = join ',', @show;
    $param{bm_height} = $height;
    $param{bm_js} = _bm_js($app->base . $app->uri, $param{bm_show}, $height);
    $app->build_page('bookmarklets.tmpl', \%param);
}

sub _bm_js {
    my($uri, $show, $height) = @_;
    qq!javascript:d=document;t=d.selection?d.selection.createRange().text:d.getSelection();void(window.open('$uri?is_bm=1&bm_show=$show&__mode=view&_type=entry&link_title='+escape(d.title)+'&link_href='+escape(d.location.href)+'&text='+escape(t),'_blank','scrollbars=yes,width=400,height=$height,status=yes,resizable=yes,scrollbars=yes'))!;
}

sub start_import {
    my $app = shift;
    my $blog_id = $app->{query}->param('blog_id');
    my %param;
    require MT::Category;
    my $iter = MT::Category->load_iter({ blog_id => $blog_id });
    my @data;
    while (my $cat = $iter->()) {
        push @data, { category_id => $cat->id,
                      category_label => $cat->label };
    }
    @data = sort { $a->{category_label} cmp $b->{category_label} }
            @data;
    $param{category_loop} = \@data;
    $app->build_page('import.tmpl', \%param);
}

sub view_log {
    my $app = shift;
    my $author = $app->{author};
    return $app->error($app->translate("Permission denied."))
        unless $author->can_view_log;
    my @log;
    require MT::Log;
    my $iter = MT::Log->load_iter(undef, { 'sort' => 'created_on' });
    my $i = 1;
    while (my $log = $iter->()) {
        my $row = { log_message => $log->message, log_ip => $log->ip };
        $row->{created_on_formatted} = format_ts("%Y.%m.%d %H:%M:%S",
            $log->created_on);
        $row->{is_odd} = $i++ % 2 ? 1 : 0;
        push @log, $row;
    }
    $log[-1]{is_last} = 1 if @log;
    my %param = ( log_entry_loop => \@log );
    $param{'reset'} = $app->{query}->param('reset');
    $app->build_page('view_log.tmpl', \%param);
}

sub reset_log {
    my $app = shift;
    my $author = $app->{author};
    return $app->error($app->translate("Permission denied."))
        unless $author->can_view_log;
    require MT::Log;
    MT::Log->remove_all;
    $app->redirect($app->uri . '?__mode=view_log&reset=1');
}

{
    my %API = (
            author => 'MT::Author',
            comment => 'MT::Comment',
            entry   => 'MT::Entry',
            template => 'MT::Template',
            blog => 'MT::Blog',
            notification => 'MT::Notification',
            templatemap => 'MT::TemplateMap',
            category => 'MT::Category',
            banlist => 'MT::IPBanList',
            ping => 'MT::TBPing',
            ping_cat => 'MT::TBPing',
        );

    sub edit_object {
        my $app = shift;
        my %param = $_[0] ? %{ $_[0] } : ();
        my $q = $app->{query};
        my $type = $q->param('_type');
        my $blog_id = $q->param('blog_id');
        my $id = $q->param('id');
        my $perms = $app->{perms};
        return $app->error($app->translate("No permissions"))
            if !$perms && $id && $type ne 'author';
        if ($id &&
            ($type eq 'blog' && !$perms->can_edit_config) ||
            ($type eq 'template' && !$perms->can_edit_templates)) {
            return $app->error($app->translate("Permission denied."));
        }
        if ($type eq 'blog' && !$id && !$app->{author}->can_create_blog) {
            return $app->error($app->translate("Permission denied."));
        }
        if ($type eq 'entry' && !$id && !$q->param('is_bm')) {
            return $app->error($app->translate("Permission denied."))
                unless $perms->can_post;
        }
        if ($type eq 'author' && $app->{author}->id != $id) {
            return $app->error($app->translate("Permission denied."));
        }
        my $class = $app->_load_driver_for($type) or return;
        my $cols = $class->column_names;
        my $obj;
        if ($id) {
            $obj = $class->load($id) or
                return $app->error($app->translate("Load failed: [_1]",
                    $class->errstr));
            if ($type eq 'entry') {
                return $app->error($app->translate("Permission denied."))
                    unless $perms->can_edit_entry($obj, $app->{author});
            }
            for my $col (@$cols) {
                $param{$col} = defined $q->param($col) ?
                    $q->param($col) : $obj->$col();
                $param{$col} = encode_html($param{$col}, 1);
            }
            if ($type eq 'entry') {
                ## Don't pass in author_id, because it will clash with the
                ## author_id parameter of the author currently logged in.
                delete $param{'author_id'};

                delete $param{'category_id'};
                if (my $cat = $obj->category) {
                    $param{category_id} = $cat->id;
                }
                $blog_id = $obj->blog_id;
                my $status = $q->param('status') || $obj->status;
                $param{"status_" . MT::Entry::status_text($status)} = 1;
                $param{"allow_comments_" . ($q->param('allow_comments') || $obj->allow_comments)} = 1;
                my $df = $q->param('created_on_manual') ||
                    format_ts("%Y-%m-%d %H:%M:%S", $obj->created_on);
                $param{created_on_formatted} = $df;
                my $comments = $obj->comments;
                my @c_data;
                my $i = 1;
                @$comments = sort { $b->created_on cmp $a->created_on }
                             @$comments;
                for my $c (@$comments) {
                    my $df = format_ts("%Y-%m-%d %H:%M:%S", $c->created_on);
                    my $author = $c->author || '[No author]';
                    push @c_data, { comment_id => $c->id,
                                    comment_author => $author,
                                    comment_created => $df,
                                    comment_odd => ($i++ % 2 ? 1 : 0) };
                }
                $param{comment_loop} = \@c_data;
                $param{num_comment_rows} = @c_data + 3;
                $param{can_send_notifications} = $perms->can_send_notifications;

                ## Load list of trackback pings sent for this entry.
                require MT::Trackback;
                require MT::TBPing;
                my $tb = MT::Trackback->load({ entry_id => $obj->id });
                my @tb_data;
                if ($tb) {
                    my $iter = MT::TBPing->load_iter({ tb_id => $tb->id },
                        { 'sort' => 'created_on',
                          direction => 'ascend' });
                    $i = 1;
                    while (my $ping = $iter->()) {
                        my $df = format_ts("%Y-%m-%d %H:%M:%S", $ping->created_on);
                        push @tb_data, { ping_id => $ping->id,
                                         ping_title => $ping->title,
                                         ping_url => $ping->source_url,
                                         ping_created => $df,
                                         ping_odd => ($i++ % 2 ? 1 : 0) };
                    }
                }
                $param{ping_loop} = \@tb_data;
                $param{num_ping_rows} = @tb_data + 3;

                ## Load next and previous entries for next/previous links
                if (my $next = $obj->next) {
                    $param{next_entry_id} = $next->id;
                }
                if (my $prev = $obj->previous) {
                    $param{previous_entry_id} = $prev->id;
                }

                $param{ping_errors} = $q->param('ping_errors');
                $param{can_view_log} = $app->{author}->can_view_log;
            } elsif ($type eq 'category') {
                require MT::Trackback;
                my $tb = MT::Trackback->load({ category_id => $obj->id });
                if ($tb) {
                    my $path = $app->{cfg}->CGIPath;
                    $path .= '/' unless $path =~ m!/$!;
                    my $script = $app->{cfg}->TrackbackScript;
                    $param{tb_url} = $path . $script . '/' . $tb->id;
                    if ($param{tb_passphrase} = $tb->passphrase) {
                        $param{tb_url} .= '/' .
                            MT::Util::encode_url($param{tb_passphrase});
                    }
                }
            } elsif ($type eq 'template') {
                $blog_id = $obj->blog_id;
                $param{has_name} = $obj->type eq 'index' ||
                                   $obj->type eq 'custom' ||
                                   $obj->type eq 'archive' ||
                                   $obj->type eq 'category' ||
                                   $obj->type eq 'individual';
                $param{has_outfile} = $obj->type eq 'index';
                $param{has_rebuild} = $obj->type eq 'index';
                $param{rebuild_me} = defined $obj->rebuild_me ?
                    $obj->rebuild_me : 1;
            } elsif ($type eq 'blog') {
                $blog_id = $obj->id;
                my $at = $obj->archive_type;
                if ($at && $at ne 'None') {
                    my @at = split /,/, $at;
                    for my $at (@at) {
                        $param{'archive_type_' . $at} = 1;
                    }
                }
                $param{'status_default_' . $obj->status_default} = 1 if
                    $obj->status_default;
                $param{'sanitize_spec_' . ($obj->sanitize_spec ? 1 : 0)} = 1;
                $param{sanitize_spec_manual} = $obj->sanitize_spec
                    if $obj->sanitize_spec;
                $param{'archive_type_preferred_' .
                    $obj->archive_type_preferred} = 1 if
                    $obj->archive_type_preferred;
                $param{words_in_excerpt} = 40
                    unless defined $param{words_in_excerpt} &&
                    $param{words_in_excerpt} ne '';
                $param{'sort_order_comments_' . $obj->sort_order_comments} = 1;
                $param{'sort_order_posts_' . $obj->sort_order_posts} = 1;
                my $lang = $obj->language || 'en';
                $param{'language_' . $lang} = 1;
                (my $offset = $obj->server_offset) =~ s![-\.]!_!g;
                $offset =~ s!_00$!!;
                $param{'server_offset_' . $offset} = 1;
                $param{'allow_comments_default_' . $obj->allow_comments_default} = 1;
                $param{cc_license_name} = MT::Util::cc_name($obj->cc_license)
                    if $obj->cc_license;

                ## Load text filters.
                my $filters = MT->all_text_filters;
                my $default_entries = $obj->convert_paras;
                my $default_comments = $obj->convert_paras_comments;
                if ($default_entries eq '1') {
                    $default_entries = '__default__';
                }
                if ($default_comments eq '1') {
                    $default_comments = '__default__';
                }
                $param{text_filters} = [];
                $param{text_filters_comments} = [];
                for my $filter (keys %$filters) {
                    my $row = {
                        filter_key => $filter,
                        filter_label => $filters->{$filter}{label},
                    };
                    my $rowc = { %$row };
                    $row->{filter_selected} = $filter eq $default_entries;
                    $rowc->{filter_selected} = $filter eq $default_comments;
                    push @{ $param{text_filters} }, $row;
                    push @{ $param{text_filters_comments} }, $rowc;
                }
                $param{text_filters} = [
                    sort { $a->{filter_key} cmp $b->{filter_key} }
                    @{ $param{text_filters} } ];
                unshift @{ $param{text_filters} }, {
                    filter_key => '0',
                    filter_label => $app->translate('None'),
                    filter_selected => !$default_entries,
                };
                unshift @{ $param{text_filters_comments} }, {
                    filter_key => '0',
                    filter_label => $app->translate('None'),
                    filter_selected => !$default_entries,
                };
            } elsif ($type eq 'comment') {
                require MT::Entry;
                if (my $entry = MT::Entry->load($obj->entry_id)) {
                    $param{entry_title} = $entry->title;
                } else {
                    $param{no_entry} = 1;
                }
            }
            $param{new_object} = 0;
        } else {
            $param{new_object} = 1;
            for my $col (@$cols) {
                $param{$col} = $q->param($col);
                $param{$col} = encode_html($param{$col}, 1);
            }
            if ($type eq 'entry') {
                delete $param{'author_id'};
                delete $param{'pinged_urls'};
                require MT::Blog;
                if ($blog_id) {
                    my $blog = MT::Blog->load($blog_id);
                    my $def_status = $q->param('status') ||
                                     $blog->status_default;
                    if ($def_status) {
                        $param{"status_" . MT::Entry::status_text($def_status)}
                            = 1;
                    }
                    $param{'allow_comments_' . (defined $q->param('allow_comments') ? $q->param('allow_comments') : $blog->allow_comments_default)} = 1;
                    $param{allow_comments} = $blog->allow_comments_default
                        unless defined $q->param('allow_comments');
                    $param{allow_pings} = $blog->allow_pings_default
                        unless defined $q->param('allow_pings');
                }
                $param{created_on_formatted} = $q->param('created_on_manual');
                if ($q->param('is_bm')) {
                    $param{selected_text} = $param{text};
                    $param{text} = sprintf qq(<a title="%s" href="%s">%s</a>\n\n%s),
                        scalar $q->param('link_title'),
                        scalar $q->param('link_href'),
                        scalar $q->param('link_title'),
                        $param{text};

                    my $show = $q->param('bm_show') || '';
                    if ($show =~ /trackback/) {
                        ## Now fetch original page and scan it for embedded
                        ## TrackBack RDF tags.
                        my $url = $q->param('link_href');
                        if (my $items = MT::Util::discover_tb($url, 1)) {
                            if (@$items == 1) {
                                $param{to_ping_urls} = $items->[0]->{ping_url};
                            } else {
                                $param{to_ping_url_loop} = $items;
                            }
                        }
                    }

                    require MT::Permission;
                    my $iter = MT::Permission->load_iter({ author_id =>
                        $app->{author}->id });
                    my @data;
                    while (my $perms = $iter->()) {
                        next unless $perms->can_post;
                        my $blog = MT::Blog->load($perms->blog_id);
                        next unless $blog;
                        push @data, { blog_id => $blog->id,
                                      blog_name => $blog->name,
                                      blog_convert_breaks => $blog->convert_paras,
                                      blog_status => $blog->status_default,
                                      blog_allow_comments =>
                                          $blog->allow_comments_default,
                                      blog_allow_pings =>
                                          $blog->allow_pings_default, };
                        $param{avail_blogs}{$blog->id} = 1;
                    }
                    $param{blog_loop} = \@data;
                }
            } elsif ($type eq 'template') {
                $param{has_name} = $q->param('type') eq 'index' ||
                                   $q->param('type') eq 'custom' ||
                                   $q->param('type') eq 'archive' ||
                                   $q->param('type') eq 'category' ||
                                   $q->param('type') eq 'individual';
                $param{has_outfile} = $q->param('type') eq 'index';
                $param{has_rebuild} = $q->param('type') eq 'index';
                $param{rebuild_me} = 1;
            } elsif ($type eq 'blog') {
                $param{server_offset_0} = 1;
            }
        }
        if ($type eq 'entry') {
            ## Load categories and process into loop for category pull-down.
            require MT::Category;
            my $iter = MT::Category->load_iter({ blog_id => $blog_id });
            my $cols = MT::Category->column_names;
            my @data;
            my $cat_id = $param{category_id};
            while (my $obj = $iter->()) {
                my $row = { };
                for my $col (@$cols) {
                    $row->{'category_' . $col} = $obj->$col();
                }
                $row->{category_is_selected} = 1
                    if $cat_id && $cat_id == $obj->id;
                push @data, $row;
            }
            @data = sort { $a->{category_label} cmp $b->{category_label} }
                    @data;
            my $top = { category_id => '',
                        category_label => $app->translate('Select') };
            $top->{category_is_selected} = 1 unless $cat_id;
            unshift @data, $top;
            $param{category_loop} = \@data;

            ## Now load user's preferences and customization for new/edit
            ## entry page.
            if ($perms) {
                my $prefs = $perms->entry_prefs || 'Advanced|Bottom';
                ($prefs, my($pos)) = split /\|/, $prefs;
                if ($prefs eq 'Basic') {
                    $param{'disp_prefs_' . $prefs} = 1;
                } elsif ($prefs eq 'Advanced') {
                    my @all = qw( category extended excerpt convert_breaks
                                  allow_comments authored_on allow_pings 
                                  ping_urls );
                    for my $p (@all) {
                        $param{'disp_prefs_show_' . $p} = 1;
                    }
                } else {
                    my @p = split /,/, $prefs;
                    for my $p (@p) {
                        $param{'disp_prefs_show_' . $p} = 1;
                    }
                }
                $param{'position_buttons_' . $pos} = 1;
                $param{disp_prefs_bar_colspan} = $param{new_object} ? 1 : 2;
            }

            ## Load text filters.
            my %entry_filters;
            if (defined(my $filter = $q->param('convert_breaks'))) {
                $entry_filters{$filter} = 1;
            } elsif ($obj) {
                %entry_filters = map { $_ => 1 }
                                 @{ $obj->text_filters };
            } else {
                my $blog = MT::Blog->load($blog_id);
                my $cb = $blog->convert_paras;
                $cb = '__default__' if $cb eq '1';
                $entry_filters{$cb} = 1;
                $param{convert_breaks} = $cb;
            }
            my $filters = MT->all_text_filters;
            $param{text_filters} = [];
            for my $filter (keys %$filters) {
                push @{ $param{text_filters} }, {
                    filter_key => $filter,
                    filter_label => $filters->{$filter}{label},
                    filter_selected => $entry_filters{$filter},
                    filter_docs => $filters->{$filter}{docs},
                };
            }
            $param{text_filters} = [
                sort { $a->{filter_key} cmp $b->{filter_key} }
                @{ $param{text_filters} } ];
            unshift @{ $param{text_filters} }, {
                filter_key => '0',
                filter_label => $app->translate('None'),
                filter_selected => (!keys %entry_filters),
            };
        } elsif ($type eq 'template') {
            $param{"type_$param{type}"} = 1;
        } elsif ($type eq 'blog') {
            my $cwd = '';
            if ($ENV{MOD_PERL}) {
                ## If mod_perl, just use the document root.
                $cwd = $app->{apache}->document_root;
            } else {
                ## Try to get the current directory; first try to use
                ## getcwd(), in case we are running with taint enabled. If
                ## that fails (inability to open directory, for example),
                ## try using cwd(). If that fails, use nothing.
                require Cwd;
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
            }
            if (!$param{site_path}) {
                $param{site_path} = $cwd;
            }
            if (!$param{archive_path}) {
                $param{archive_path} = File::Spec->catdir($cwd, 'archives');
            }
            if (!$param{site_url}) {
                $param{site_url} = $app->base . '/';
            }
            if (!$param{archive_url}) {
                $param{archive_url} = $param{site_url} . 'archives/';
            }
        } elsif ($type eq 'author') {
            my $langs = $app->supported_languages;
            my @data;
            my $preferred = $obj && $obj->preferred_language ?
                $obj->preferred_language : 'en-us';
            for my $tag (keys %$langs) {
                my $row = { l_tag => $tag, l_name => $langs->{$tag} };
                $row->{l_selected} = 1 if $preferred eq $tag;
                push @data, $row;
            }
            $param{languages} = [ sort { $a->{l_name} cmp $b->{l_name} }
                                  @data ];
        }
        for my $p ($q->param) {
            $param{$p} = $q->param($p) if $p =~ /^saved/;
        }
        if ($q->param('is_bm')) {
            my $show = $q->param('bm_show') || '';
            if ($show) {
                my @show = map "show_$_", split /,/, $show;
                @param{ @show } = (1) x @show;
            }
            if ($show =~ /category/) {
                my $iter = MT::Category->load_iter({}, { 'sort' => 'label' });
                my @i;
                my @c_data;
                my %avail_blogs = %{ $param{avail_blogs} };
                while (my $cat = $iter->()) {
                    my $blog_id = $cat->blog_id;
                    next unless $avail_blogs{$blog_id};
                    my $label = $cat->label;
                    $label =~ s!'!\\'!g;
                    $i[$blog_id] = 0 unless defined $i[$blog_id];
                    push @c_data, {
                            category_blog_id => $blog_id,
                            category_index => $i[$blog_id]++,
                            category_id => $cat->id,
                            category_label => $label
                    };
                }
                $param{category_loop} = \@c_data;
            }
            return $app->build_page("bm_entry.tmpl", \%param);
        } elsif ($param{output}) {
            return $app->build_page($param{output}, \%param);
        } else {
            return $app->build_page("edit_${type}.tmpl", \%param);
        }
    }

    sub save_object {
        my $app = shift;
        my $q = $app->{query};
        my $type = $q->param('_type');
        my $id = $q->param('id');
        my $perms = $app->{perms};
        return $app->error($app->translate("No permissions"))
            if !$perms && $id && $type ne 'author';
        if ($id &&
            ($type eq 'blog' && !$perms->can_edit_config) ||
            ($type eq 'template' && !$perms->can_edit_templates)) {
            return $app->error($app->translate("Permission denied."))
        }
        if ($type eq 'blog' && !$id && !$app->{author}->can_create_blog) {
            return $app->error($app->translate("Permission denied."));
        }
        if ($type eq 'author') {
            ## If we are saving an author profile, we need to do some
            ## password maintenance. First make sure that the two
            ## passwords match...
            if ($q->param('pass') ne $q->param('pass_verify')) {
                my %param = (error => 'Passwords do not match.');
                my $qual = $id ? '' : 'author_state_';
                for my $f (qw( name email url )) {
                    $param{$qual . $f} = $q->param($f);
                }
                $param{checked_blog_ids} = { map { $_ => 1 }
                                             $q->param('add_to_blog') };
                my $meth = $id ? 'edit_object' : 'edit_permissions';
                return $app->$meth(\%param);
            }

            ## ... then check to make sure that the author isn't trying
            ## to change his/her username to one that already exists.
            require MT::Author;
            my $name = $q->param('name');
            my $existing = MT::Author->load({ name => $name });
            if ($existing && (!$q->param('id') ||
                $existing->id != $q->param('id'))) {
                my %param = (error => 'An author by that name already exists.');
                my $qual = $id ? '' : 'author_state_';
                for my $f (qw( name email url )) {
                    $param{$qual . $f} = $q->param($f);
                }
                $param{checked_blog_ids} = { map { $_ => 1 }
                                             $q->param('add_to_blog') };
                my $meth = $id ? 'edit_object' : 'edit_permissions';
                return $app->$meth(\%param);
            }
        }
        my $class = $app->_load_driver_for($type) or return;
        my($obj);
        if ($id) {
            $obj = $class->load($id);
        } else {
            $obj = $class->new;
        }
        my $names = $obj->column_names;
        my %values = map { $_ => scalar $q->param($_) } @$names;
        $obj->set_values(\%values);
        if ($type eq 'author') {
            if (my $pass = $q->param('pass')) {
                $obj->set_password($pass);
            }
            ## If this is an author editing his/her profile, $id will be
            ## some defined value; if so we should update the author's
            ## cookie to reflect any changes made to username and password.
            ## Otherwise, this is a new user, and we shouldn't update the
            ## cookie.
            if ($id) {
                my($remember) = (split /::/, $app->{cookies}->{user}->value)[2];
                my %arg = (
                    -name => 'user',
                    -value => join('::', $obj->name, $obj->password, $remember),
                    -path => $app->path,
                );
                $arg{-expires} = '+10y' if $remember;
                $app->bake_cookie(%arg);
            }
        } elsif ($type eq 'template') {
            $obj->rebuild_me(0) unless $q->param('rebuild_me');
            ## Strip linefeed characters.
            (my $text = $values{text}) =~ tr/\r//d;
            $obj->text($text);
        } elsif ($type eq 'blog') {
            if ($q->param('cfg_screen')) {
                my @fields = qw( email_new_comments allow_comment_html
                                 autolink_urls allow_comments_default
                                 convert_paras_comments
                                 allow_anon_comments ping_weblogs ping_blogs
                                 allow_pings_default email_new_pings
                                 autodiscover_links );
                for my $cb (@fields) {
                    $obj->$cb(0) if !defined $q->param($cb);
                }
            } else {
                $obj->is_dynamic(0) unless defined $q->param('is_dynamic');
            }

            if ($obj->sanitize_spec eq '1') {
                $obj->sanitize_spec(scalar $q->param('sanitize_spec_manual'));
            }

            ## If this is a new blog, set the preferences and archive
            ## settings to the defaults.
            if (!$id) {
                $obj->days_on_index(7);
                $obj->words_in_excerpt(40);
                $obj->sort_order_posts('descend');
                $obj->language('en');
                $obj->sort_order_comments('ascend');
                $obj->file_extension('html');
                $obj->convert_paras('__default__');
                $obj->allow_comments_default(1);
                $obj->allow_pings_default(0);
                $obj->convert_paras_comments(1);
                $obj->sanitize_spec(0);
                $obj->ping_weblogs(0);
                $obj->ping_blogs(0);
                $obj->archive_type('Individual,Monthly');
                $obj->archive_type_preferred('Individual');
                $obj->status_default(1);
            }
        } elsif ($type eq 'category') {
            $obj->allow_pings(0) if !defined $q->param('allow_pings');
            if (defined(my $pass = $q->param('tb_passphrase'))) {
                $obj->{__tb_passphrase} = $pass;
            }
        }
        $obj->save or
            return $app->error($app->translate(
                "Saving object failed: [_1]", $obj->errstr));
        if ($type eq 'blog' && !$id) {

            ## If this is a new blog, we need to set up a permissions
            ## record for the existing user.
            require MT::Permission;
            my $perms = MT::Permission->new;
            $perms->author_id($app->{author}->id);
            $perms->blog_id($obj->id);
            $perms->set_full_permissions;
            $perms->save;

            ## Load default templates into new blog database.
            my $tmpl_list;
            eval { $tmpl_list = require 'MT/default-templates.pl' };
            return $app->error($app->translate(
                "Can't find default template list; where is " .
                "'default-templates.pl'?")) if
                $@ || !$tmpl_list || ref($tmpl_list) ne 'ARRAY' || !@$tmpl_list;
            require MT::Template;
            my @arch_tmpl;
            for my $val (@$tmpl_list) {
                $val->{text} = $app->translate_templatized($val->{text});
                my $tmpl = MT::Template->new;
                $tmpl->set_values($val);
                $tmpl->blog_id($obj->id);
                $tmpl->save or
                    return $app->error($app->translate(
                        "Populating blog with default templates failed: [_1]",
                        $tmpl->errstr));
                if ($val->{type} eq 'archive' || $val->{type} eq 'category' ||
                    $val->{type} eq 'individual') {
                    push @arch_tmpl, $tmpl;
                }
            }

            ## Set up mappings from new templates to archive types.
            for my $tmpl (@arch_tmpl) {
                my(@at);
                if ($tmpl->type eq 'archive') {
                    @at = qw( Daily Weekly Monthly );
                } elsif ($tmpl->type eq 'category') {
                    @at = qw( Category );
                } elsif ($tmpl->type eq 'individual') {
                    @at = qw( Individual );
                }
                require MT::TemplateMap;
                for my $at (@at) {
                    my $map = MT::TemplateMap->new;
                    $map->archive_type($at);
                    $map->is_preferred(1);
                    $map->template_id($tmpl->id);
                    $map->blog_id($tmpl->blog_id);
                    $map->save
                        or return $app->error($app->translate(
                            "Setting up mappings failed: [_1]", $map->errstr));
                }
            }
        } elsif ($type eq 'author' && !$id) {
            my $author_id = $obj->id;
            for my $blog_id ($q->param('add_to_blog')) {
                my $pe = MT::Permission->new;
                $pe->blog_id($blog_id);
                $pe->author_id($author_id);
                $pe->can_post(1);
                $pe->save;
            }
        }
        my $blog_id = $q->param('blog_id');
        if ($type eq 'blog') {
            $blog_id = $obj->id;
        }
        if ($type eq 'author' && !$id) {
            return $app->redirect($app->uri .
                '?__mode=edit_permissions&author_id=' . $obj->id);
        } elsif ($type eq 'notification') {
            return $app->redirect($app->uri .
                '?__mode=list&_type=notification&blog_id=' . $blog_id .
                '&saved=' . $obj->email);
        } elsif ($type eq 'comment') {
            return $app->redirect($app->uri .
                '?__mode=view&_type=entry&id=' . $obj->entry_id .
                '&blog_id=' . $blog_id . '&saved_comment=1');
        } elsif (my $cfg_screen = $q->param('cfg_screen')) {
            return $app->redirect($app->uri .
                "?__mode=$cfg_screen&blog_id=" . $obj->id . '&saved=1');
        } elsif ($type eq 'banlist') {
            return $app->redirect($app->uri .
                '?__mode=list&_type=banlist&blog_id=' . $blog_id .
                '&saved=' . $obj->ip);
        } else {
            return $app->redirect($app->uri .
                '?__mode=view&_type=' . $type . '&id=' . $obj->id .
                '&blog_id=' . $blog_id . '&saved=1');
        }
    }

    sub list_objects {
        my $app = shift;
        my $q = $app->{query};
        my $type = $q->param('_type');
        my $perms = $app->{perms};
        return $app->error($app->translate("No permissions"))
            unless $type eq 'author' || $perms;
        if ($perms &&
            (($type eq 'blog' && !$perms->can_edit_config) ||
             ($type eq 'template' && !$perms->can_edit_templates) ||
             ($type eq 'author' && !$perms->can_edit_authors))) {
            return $app->error($app->translate("Permission denied."));
        }
        my $id = $q->param('id');
        my $class = $app->_load_driver_for($type) or return;
        my $blog_id = $q->param('blog_id');
        my %param;
        my %terms;
        my $cols = $class->column_names;
        for my $name (@$cols) {
            $terms{blog_id} = $blog_id, last
                if $name eq 'blog_id';
        }
        my $iter = $class->load_iter(\%terms);
        my(@data, @index_data, @custom_data, @archive_data);
        my(%authors);
        while (my $obj = $iter->()) {
            my $row = $obj->column_values;
            if (my $ts = $obj->created_on) {
                $row->{created_on_formatted} = format_ts("%Y.%m.%d", $ts);
            }
            if ($type eq 'author') {
                $authors{ $obj->id } = $obj->name;
            }
            if ($type eq 'template') {
                if ($obj->type eq 'index') {
                    push @index_data, $row;
                    $row->{rebuild_me} = defined $row->{rebuild_me} ?
                        $row->{rebuild_me} : 1;
                } elsif ($obj->type eq 'custom') {
                    push @custom_data, $row;
                } elsif ($obj->type eq 'archive' || $obj->type eq 'category' ||
                         $obj->type eq 'individual') {
                    push @archive_data, $row;
                } else {
                    $param{'template_' . $obj->type} = $obj->id;
                }
            } else {
                $row->{is_odd} = @data % 2 ? 0 : 1;
                push @data, $row;
            }
        }
        if ($type eq 'author') {
            my $this_author_id = $app->{author}->id;
            for my $row (@data) {
                $row->{added_by} = $authors{$row->{created_by}}
                    if $row->{created_by};
                $row->{can_delete} = 1
                    if (($row->{created_by} &&
                       $row->{created_by} == $this_author_id) ||
                       $row->{id} == $this_author_id);
            }
        }
        if ($type eq 'notification') {
            @data = sort { $a->{email} cmp $b->{email} } @data;
            for my $i (0..$#data) {
                $data[$i]->{is_odd} = $i % 2 ? 0 : 1;
            }
        }
        if ($type eq 'template') {
            for my $ref (\@index_data, \@custom_data, \@archive_data) {
                @$ref = sort { $a->{name} cmp $b->{name} } @$ref;
                for my $i (0..$#$ref) {
                    $ref->[$i]{is_odd} = $i % 2 ? 0 : 1;
                }
            }
            $param{object_index_loop} = \@index_data;
            $param{object_custom_loop} = \@custom_data;
            $param{object_archive_loop} = \@archive_data;
        } else {
            $param{object_loop} = \@data;
        }
        $param{object_count} = scalar @data;
        $param{saved} = $q->param('saved');
        $param{saved_deleted} = $q->param('saved_deleted');
        if ($type eq 'banlist') {
            $app->build_page('cfg_banlist.tmpl', \%param);
        } else {
            $app->build_page("list_${type}.tmpl", \%param);
        }
    }

    sub delete_confirm {
        my $app = shift;
        my %param = ( type => scalar $app->{query}->param('_type') );
        my @data;
        for my $id ($app->{query}->param('id')) {
            push @data, { id => $id };
        }
        $param{id_loop} = \@data;
        $param{num} = scalar @data;
        $param{'type_' . $param{type}} = 1;
        $param{is_zero} = @data == 0;
        $param{is_one} = @data == 1;
        $param{is_many} = !$param{is_zero} && !$param{is_one};
        $param{thisthese} = $param{is_one} ? 'this' : 'these';
        $param{is_power_edit} = $app->{query}->param('is_power_edit') ? 1 : 0;
        $app->build_page('delete_confirm.tmpl', \%param);
    }

    sub delete {
        my $app = shift;
        my $q = $app->{query};
        my $type = $q->param('_type');
        my $class = $app->_load_driver_for($type) or return;
        my $perms = $app->{perms};
        my $author = $app->{author};

        ## Construct an anonymous subroutine $auth_check to check if
        ## the user has permission to delete each object being deleted.
        my $auth_check = sub { };
        if ($type eq 'comment') {
            $auth_check = sub {
                my($obj) = @_;
                require MT::Entry;
                my $entry = MT::Entry->load($obj->entry_id);
                $perms->can_edit_entry($entry, $author);
            };
        } elsif ($type eq 'ping') {
            $auth_check = sub {
                my($obj) = @_;
                require MT::Trackback;
                require MT::Entry;
                my $tb = MT::Trackback->load($obj->tb_id);
                my $entry = MT::Entry->load($tb->entry_id);
                $perms->can_edit_entry($entry, $author);
            };
        } elsif ($type eq 'ping_cat') {
            $auth_check = sub { $perms->can_edit_categories };
        } elsif ($type eq 'entry') {
            $auth_check = sub { $perms->can_edit_entry($_[0], $author) };
        } elsif ($type eq 'notification') {
            $auth_check = sub { $perms->can_edit_notifications };
        } elsif ($type eq 'template') {
            $auth_check = sub { $perms->can_edit_templates };
        } elsif ($type eq 'blog') {
            $auth_check = sub {
                require MT::Permission;
                my $perms = MT::Permission->load({
                    author_id => $author->id,
                    blog_id => $_[0]->id,
                });
                $perms->can_edit_config;
            };
        } elsif ($type eq 'author') {
            $auth_check = sub { $_[0]->id == $author->id ||
                ($_[0]->created_by && $_[0]->created_by == $author->id) };
        } elsif ($type eq 'category') {
            $auth_check = sub { $perms->can_edit_categories };
        } elsif ($type eq 'templatemap') {
            $auth_check = sub { $perms->can_edit_config };
        } elsif ($type eq 'banlist') {
            $auth_check = sub { $perms->can_edit_config };
        }

        my($entry_id, $cat_id);
        for my $id ($q->param('id')) {
            my $obj = $class->load($id);
            next unless $obj;
            return $app->error($app->translate("Permission denied."))
                unless $auth_check->($obj);
            if (!$entry_id) {
                if ($type eq 'comment') {
                    $entry_id = $obj->entry_id;
                } elsif ($type eq 'ping' || $type eq 'ping_cat') {
                    require MT::Trackback;
                    my $tb = MT::Trackback->load($obj->tb_id);
                    $entry_id = $tb->entry_id;
                    $cat_id = $tb->category_id;
                }
            }
            $obj->remove;
        }
        my $blog_id = $q->param('blog_id');
        my %types = (
            comment => "__mode=view&_type=entry&blog_id=$blog_id&id=$entry_id&",
            ping => "__mode=view&_type=entry&blog_id=$blog_id&id=$entry_id&",
            ping_cat => "__mode=tb_cat_pings&blog_id=$blog_id&category_id=$cat_id&",
            entry => "__mode=list_entries&blog_id=$blog_id&",
            notification => "__mode=list&_type=notification&blog_id=$blog_id&",
            template => "__mode=list&_type=template&blog_id=$blog_id&",
            blog => "",
            author => "__mode=list&_type=author&",
            category => "__mode=list_cat&blog_id=$blog_id&",
            templatemap => "__mode=cfg_archives&id=$blog_id&blog_id=$blog_id&",
            banlist => "__mode=list&_type=banlist&blog_id=$blog_id&",
        );
        my $url = $app->uri . '?' . $types{$type} .
            ($type eq 'ping' ? 'saved_deleted_ping=1' : 'saved_deleted=1');
        if ($q->param('is_power_edit')) {
            $url .= '&is_power_edit=1';
        }
        return $app->build_page('reload_opener.tmpl', { url => $url });
    }

    sub _load_driver_for {
        my $app = shift;
        my($type) = @_;
        my $class = $API{$type} or
            return $app->error($app->translate("Unknown object type [_1]",
                $type));
        eval "use $class;";
        return $app->error($app->translate(
            "Loading object driver [_1] failed: [_2]", $class, $@)) if $@;
        $class;
    }
}

sub show_upload_html {
    my $app = shift;
    defined(my $text = $app->_process_post_upload) or return;
    $app->build_page('show_upload_html.tmpl',
        { upload_html => encode_html($text, 1) });
}

sub start_upload_entry {
    my $app = shift;
    my $q = $app->{query};
    $q->param('_type', 'entry');
    defined(my $text = $app->_process_post_upload) or return;
    $q->param('text', $text);
    $app->edit_object;
}

sub _process_post_upload {
    my $app = shift;
    my $q = $app->{query};
    my($url, $width, $height) = map $q->param($_), qw( url width height );
    my $blog_id = $q->param('blog_id');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    my($thumb, $thumb_width, $thumb_height);
    if ($thumb = $q->param('thumb')) {
        require MT::Image;
        my $base_path = $q->param('site_path') ?
            $blog->site_path : $blog->archive_path;
        my $file = $q->param('fname');
        if ($file =~ m!\.\.|\0|\|!) {
            return $app->error($app->translate("Invalid filename '[_1]'", $file));
        }
        my $i_file = File::Spec->catfile($base_path, $file);
        ## Untaint. We checked $file for security holes above.
        ($i_file) = $i_file =~ /(.+)/s;
        my $fmgr = $blog->file_mgr;
        my $data = $fmgr->get_data($i_file, 'upload')
            or return $app->error($app->translate(
                "Reading '[_1]' failed: [_2]", $i_file, $fmgr->errstr));
        my $img = MT::Image->new( Data => $data,
                                  Type => scalar $q->param('image_type') )
            or return $app->error($app->translate(
                "Thumbnail failed: [_1]", MT::Image->errstr));
        my($w, $h) = map $q->param($_), qw( thumb_width thumb_height );
        (my($blob), $thumb_width, $thumb_height) =
            $img->scale( Width => $w, Height => $h )
            or return $app->error($app->translate("Thumbnail failed: [_1]",
                $img->errstr));
        require File::Basename;
        my($base, $path, $ext) = File::Basename::fileparse($i_file, '\.[^.]*');
        my $t_file = $path . $base . '-thumb' . $ext;
        $fmgr->put_data($blob, $t_file, 'upload')
            or return $app->error($app->translate(
                "Error writing to '[_1]': [_2]", $t_file, $fmgr->errstr));
        my $url = $q->param('site_path') ? $blog->site_url : $blog->archive_url;
        $url .= '/' unless $url =~ m!/$!;
        $t_file =~ s!^\Q$base_path\E\\?/?!!;
        $thumb = $url . $t_file;
    }
    if ($q->param('popup')) {
        require MT::Template;
        if (my $tmpl = MT::Template->load({ blog_id => $blog_id,
                                            type => 'popup_image' })) {
            (my $base = $q->param('fname')) =~ s!\.[^.]*$!!;
            if ($base =~ m!\.\.|\0|\|!) {
                return $app->error($app->translate(
                    "Invalid basename '[_1]'", $base));
            }
            my $ext = '.' . $blog->file_extension || 'html';
            require MT::Template::Context;
            my $ctx = MT::Template::Context->new;
            $ctx->stash('image_url', $url);
            $ctx->stash('image_width', $width);
            $ctx->stash('image_height', $height);
            my $popup = $tmpl->build($ctx);
            my $fmgr = $blog->file_mgr;
            my $base_path = $q->param('site_path') ?
                $blog->site_path : $blog->archive_path;
            my $p_file = File::Spec->catfile($base_path, $base . $ext);

            ## If the popup filename already exists, we don't want to overwrite
            ## it, because it could contain valuable data; so we'll just make
            ## sure to generate the name uniquely.
            my($i, $full_base) = (0, $base . $ext);
            while ($fmgr->exists($p_file)) {
                $full_base = $base . ++$i . $ext;
                $p_file = File::Spec->catfile($base_path, $full_base);
            }
            ## Untaint. We have checked for security holes above, so we
            ## should be safe.
            ($p_file) = $p_file =~ /(.+)/s;
            $fmgr->put_data($popup, $p_file, 'upload')
                or return $app->error($app->translate(
                    "Error writing to '[_1]': [_2]", $p_file, $fmgr->errstr));
            $url = $q->param('site_path') ?
                $blog->site_url : $blog->archive_url;
            $url .= '/' unless $url =~ m!/$!;
            $full_base =~ s!^/!!;
            $url .= $full_base;
        }
        my $link = $thumb ? qq(<img src="$thumb" width="$thumb_width" height="$thumb_height" border="0" />) : "View image";
        return <<HTML;
<a href="$url" onclick="window.open('$url','popup','width=$width,height=$height,scrollbars=no,resizable=no,toolbar=no,directories=no,location=no,menubar=no,status=no,left=0,top=0'); return false">$link</a>
HTML
    } elsif ($q->param('include')) {
        (my $fname = $url) =~ s!^.*/!!;
        if ($thumb) {
            return <<HTML;
<a href="$url"><img alt="$fname" src="$thumb" width="$thumb_width" height="$thumb_height" border="0" /></a>
HTML
        } else {
            return <<HTML;
<img alt="$fname" src="$url" width="$width" height="$height" border="0" />
HTML
        }
    } elsif ($q->param('link')) {
        return <<HTML;
<a href="$url">Download file</a>
HTML
    }
}

sub list_entries {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    if (!$perms->can_edit_all_posts && !$perms->can_post) {
        return $app->error($app->translate("Permission denied."));
    }
    my $id = $q->param('id');
    if (!$id) {
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_post;
    }
    my %param;
    my $blog_id = $q->param('blog_id');
    my %terms = (blog_id => $blog_id);
    my $limit = $q->param('limit') || 20;
    $param{"limit_" . $limit} = 1;
    my $offset = $q->param('offset') || 0;
    ## We load $limit + 1 records so that we can easily tell if we have a
    ## page of next entries to link to. Obviously we only display $limit
    ## entries.
    my %arg = (
            'sort' => 'created_on',
            direction => 'descend',
            ($limit eq 'none' ? () : (limit => $limit + 1)),
            ($offset ? (offset => $offset) : ()),
    );
    if (!$perms->can_edit_all_posts) {
        $terms{author_id} = $app->{author}->id;
    }
    if ((my $filter_col = $q->param('filter')) &&
        (my $val = $q->param('filter_val'))) {
        if ($filter_col eq 'category_id') {
            $arg{'join'} = [ 'MT::Placement', 'entry_id',
                             { category_id => $val }, { unique => 1 } ];
        } else {
            $terms{$filter_col} = $val;
        }
        (my $url_val = $val) =~
            s!([^a-zA-Z0-9_.-])!uc sprintf "%%%02x", ord($1)!eg;
        $param{filter_args} = "&filter=$filter_col&filter_val=$url_val";
    }
    require MT::Entry;
    require MT::Category;
    require MT::Author;
    my($iter);

    ## Load list of categories for display in filter pulldown (and selection
    ## pulldown on power edit page).
    my(@c_data, %cats);
    $iter = MT::Category->load_iter({ blog_id => $blog_id });
    while (my $cat = $iter->()) {
        $cats{ $cat->id } = $cat->label;
        push @c_data, { category_id => $cat->id,
                        category_label => MT::Util::encode_js($cat->label) };
    }
    @c_data = sort { $a->{category_label} cmp $b->{category_label} } @c_data;
    my $i = 0;
    for my $row (@c_data) {
        $row->{category_index} = $i++;
    }
    $param{category_loop} = \@c_data;

    ## Load list of authors for display in filter pulldown (and selection
    ## pulldown on power edit page).
    my(@a_data, %authors);
    $iter = MT::Author->load_iter(undef, {
        'join' => [ 'MT::Permission', 'author_id',
                    { blog_id => $blog_id } ] });
    while (my $author = $iter->()) {
        $authors{ $author->id } = $author->name;
        push @a_data, { author_id => $author->id,
                        author_name => MT::Util::encode_js($author->name) };
    }
    @a_data = sort { $a->{author_name} cmp $b->{author_name} } @a_data;
    $i = 0;
    for my $row (@a_data) {
        $row->{author_index} = $i++;
    }
    $param{author_loop} = \@a_data;
    $iter = MT::Entry->load_iter(\%terms, \%arg);
    my @data;
    $i = 1;
    my $is_power_edit = $q->param('is_power_edit');
    my(@cat_list, @auth_list);
    if ($is_power_edit) {
        @cat_list = sort { $cats{$a} cmp $cats{$b} } keys %cats;
        @auth_list = sort { $authors{$a} cmp $authors{$b} } keys %authors;
    }
    while (my $obj = $iter->()) {
        my $row = $obj->column_values;
        $row->{created_on_formatted} = format_ts("%Y.%m.%d", $obj->created_on);
        $row->{created_on_time_formatted} =
            format_ts("%Y-%m-%d %H:%M:%S", $obj->created_on);
        $row->{author_name} = $authors{ $obj->author_id };
        $row->{category_name} = $obj->category ? $obj->category->label : '';
        $row->{title_short} = $obj->title;
        unless ($row->{title_short}) {
            my $title = remove_html($obj->text);
            $row->{title_short} = substr($title, 0, 22) . '...';
        }
        $row->{title_short} = substr($row->{title_short}, 0, 22) . '...'
            if length($row->{title_short}) > 25;
        $row->{title_short} = encode_html($row->{title_short}, 1);
        $row->{status_text} =
            $app->translate(MT::Entry::status_text($obj->status));
        $row->{"status_$row->{status_text}"} = 1;
        $row->{entry_odd} = $i++ % 2 ? 1 : 0;
        $row->{has_edit_access} = $perms->can_edit_all_posts ||
            $obj->author_id == $app->{author}->id;
        if ($is_power_edit) {
            $row->{is_editable} = $row->{has_edit_access};

            ## This is annoying. In order to generate and pre-select the
            ## category, author, and status pull down menus, we need to
            ## have a separate *copy* of the list of categories and
            ## authors for every entry listed, so that each row in the list
            ## can "know" whether it is selected for this entry or not.
            my @this_c_data;
            my $this_category_id = $obj->category ? $obj->category->id : undef;
            for my $c_id (@cat_list) {
                push @this_c_data, { category_label => $cats{$c_id},
                                     category_id => $c_id };
                $this_c_data[-1]{category_is_selected} = $this_category_id &&
                    $this_category_id == $c_id ? 1 : 0;
            }
            $row->{row_category_loop} = \@this_c_data;

            my @this_a_data;
            my $this_author_id = $obj->author_id;
            for my $a_id (@auth_list) {
                push @this_a_data, { author_name => $authors{$a_id},
                                     author_id => $a_id };
                $this_a_data[-1]{author_is_selected} = $this_author_id &&
                    $this_author_id == $a_id ? 1 : 0;
            }
            $row->{row_author_loop} = \@this_a_data;
        }
        push @data, $row;
    }
    if ($limit ne 'none') {
        ## We tried to load $limit + 1 entries above; if we actually got
        ## $limit + 1 back, we know we have another page of entries.
        my $have_next_entry = scalar @data == $limit + 1;
        pop @data if $have_next_entry;
        if ($offset) {
            $param{prev_offset} = 1;
            $param{prev_offset_val} = $offset - $limit;
        }
        if ($have_next_entry) {
            $param{next_offset} = 1;
            $param{next_offset_val} = $offset + $limit;
        }
    }
    $param{object_loop} = \@data;
    $param{is_power_edit} = $is_power_edit;
    $param{saved_deleted} = $q->param('saved_deleted');
    $param{saved} = $q->param('saved');
    $param{limit} = $limit;
    $param{offset} = $offset;
    $app->build_page("list_entry.tmpl", \%param);
}

sub save_entries {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_post || $perms->can_edit_all_posts;
    my $q = $app->{query};
    my @p = $q->param;
    require MT::Entry;
    require MT::Placement;
    my $blog_id = $q->param('blog_id');
    my $this_author_id = $app->{author}->id;
    for my $p (@p) {
        next unless $p =~ /^category_id_(\d+)/;
        my $id = $1;
        my $entry = MT::Entry->load($id);
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_edit_entry($entry, $app->{author});
        my $author_id = $q->param('author_id_' . $id);
        $entry->author_id($author_id ? $author_id : 0);
        $entry->status(scalar $q->param('status_' . $id));
        $entry->title(scalar $q->param('title_' . $id));
        my $co = $q->param('created_on_' . $id);
        unless ($co =~
            m!(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?!) {
            return $app->error($app->translate(
                "Invalid date '[_1]'; authored on dates must be in the " .
                "format YYYY-MM-DD HH:MM:SS.", $co));
        }
        my $s = $6 || 0;
        my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $s;
        $entry->created_on($ts);
        $entry->save
            or return $app->error($app->translate(
                "Saving entry '[_1]' failed: [_2]", $entry->title,
                $entry->errstr));
        my $cat_id = $q->param($p);
        my $place = MT::Placement->load({ entry_id => $id,
                                          is_primary => 1 });
        if ($place && !$cat_id) {
            $place->remove
                or return $app->error($app->translate(
                    "Removing placement failed: [_1]", $place->errstr));
        }
        elsif ($cat_id) {
            unless ($place) {
                $place = MT::Placement->new;
                $place->entry_id($id);
                $place->blog_id($blog_id);
                $place->is_primary(1);
            }
            $place->category_id(scalar $q->param($p));
            $place->save
                or return $app->error($app->translate(
                    "Saving placement failed: [_1]", $place->errstr));
        }
    }
    my $url = $app->uri . '?__mode=list_entries&blog_id=' . $blog_id .
              '&is_power_edit=1' . $q->param('filter_args');
    if (my $o = $q->param('offset')) {
        $url .= '&offset=' . $o;
    }
    if (my $l = $q->param('limit')) {
        $url .= '&limit=' . $l;
    }
    $app->redirect($url . '&saved=1');
}

sub save_entry {
    my $app = shift;
    my $q = $app->{query};
    if ($q->param('preview_entry')) {
        return $app->preview_entry;
    } elsif ($q->param('reedit')) {
        $q->param('_type', 'entry');
        return $app->edit_object;
    }
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    my $id = $q->param('id');
    if (!$id) {
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_post;
    }
    require MT::Entry;
    my($obj);
    if ($id) {
        $obj = MT::Entry->load($id);
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_edit_entry($obj, $app->{author});
    } else {
        $obj = MT::Entry->new;
    }
    my $status_old = $id ? $obj->status : 0;
    my $names = $obj->column_names;
    ## Get rid of category_id param, because we don't want to just set it
    ## in the Entry record; save it for later when we will set the Placement.
    my $cat_id = $q->param('category_id');
    $app->delete_param('category_id');
    if ($id) {
        ## Delete the author_id param (if present), because we don't want to
        ## change the existing author.
        $app->delete_param('author_id');
    }
    my %values = map { $_ => scalar $q->param($_) } @$names;
    ## Strip linefeed characters.
    for my $col (qw( text excerpt text_more keywords )) {
        $values{$col} =~ tr/\r//d if $values{$col};
    }
    $obj->set_values(\%values);
    $obj->allow_pings(0)
        if !defined $q->param('allow_pings') ||
           $q->param('allow_pings') eq '';
    my $co = $q->param('created_on_manual');
    if ($co && $co ne $q->param('created_on_old')) {
        unless ($co =~
            m!(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?!) {
            return $app->error($app->translate(
                "Invalid date '[_1]'; authored on dates must be in the " .
                "format YYYY-MM-DD HH:MM:SS.", $co));
        }
        my $s = $6 || 0;
        my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $s;
        $obj->created_on($ts);
    }
    my $is_new = $obj->id ? 0 : 1;
    $obj->save or
        return $app->error($app->translate(
            "Saving entry failed: [_1]", $obj->errstr));
    $app->log("'" . $app->{author}->name . "' added entry #" . $obj->id)
        if $is_new;

    ## Now that the object is saved, we can be certain that it has an
    ## ID. So we can now add/update/remove the primary placement.
    require MT::Placement;
    my $place = MT::Placement->load({ entry_id => $obj->id, is_primary => 1 });
    if ($cat_id) {
        unless ($place) {
            $place = MT::Placement->new;
            $place->entry_id($obj->id);
            $place->blog_id($obj->blog_id);
            $place->is_primary(1);
        }
        $place->category_id($cat_id);
        $place->save;
    } else {
        if ($place) {
            $place->remove;
        }
    }

    ## If the saved status is RELEASE, or if the *previous* status was
    ## RELEASE, then rebuild entry archives, indexes, and send the
    ## XML-RPC ping(s). Otherwise the status was and is HOLD, and we
    ## don't have to do anything.
    if ($obj->status == MT::Entry::RELEASE() ||
        $status_old eq MT::Entry::RELEASE()) {
        return $app->redirect($app->uri . '?__mode=start_rebuild&blog_id=' .
            $obj->blog_id . '&next=0&type=entry-' . $obj->id .
            '&entry_id=' . $obj->id . '&is_bm=' . $q->param('is_bm') .
            '&is_new=' . $is_new . '&old_status=' . $status_old);
    }
    $app->_finish_rebuild_ping($obj, !$id);
}

sub _finish_rebuild_ping {
    my $app = shift;
    my($entry, $is_new, $ping_errors) = @_;
    if ($app->{query}->param('is_bm')) {
        require MT::Blog;
        my $blog = MT::Blog->load($entry->blog_id);
        my %param = ( blog_id => $blog->id,
                      blog_name => $blog->name,
                      blog_url => $blog->site_url,
                      entry_id => $entry->id,
                      status_released =>
                          $entry->status == MT::Entry::RELEASE() );
        $app->build_page("bm_posted.tmpl", \%param);
    } else {
        $app->redirect($app->uri . '?__mode=view&_type=entry&blog_id=' .
                       $entry->blog_id . '&id=' . $entry->id .
                       ($is_new ? '&saved_added=1' : '&saved_changes=1') .
                       ($ping_errors ? '&ping_errors=1' : ''));
    }
}

sub edit_placements {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    my $q = $app->{query};
    my $entry_id = $q->param('entry_id');
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id);
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_edit_entry($entry, $app->{author});
    my %param;
    require MT::Category;
    my %cats;
    my $blog_id = $q->param('blog_id');
    my $iter = MT::Category->load_iter({ blog_id => $blog_id });
    my $i = 0;
    while (my $cat = $iter->()) {
        $cats{ $cat->id } = $cat->label;
    }
    require MT::Placement;
    $iter = MT::Placement->load_iter({ entry_id => $entry_id,
                                       is_primary => 0 });
    my $prim_category_id = $entry->category ? $entry->category->id : undef;
    my(@p_data, %place);
    while (my $place = $iter->()) {
        $place{$place->category_id} = 1;
        push @p_data, { place_category_id => $place->category_id,
                        place_category_label => $cats{$place->category_id} };
    }
    $param{placement_loop} = \@p_data;
    my @c_data;
    for my $id (keys %cats) {
        if (!exists $place{$id} && (!$prim_category_id || $prim_category_id
            != $id)) {
            push @c_data, { category_id => $id,
                            category_label => $cats{ $id } };
        }
    }
    @c_data = sort { $a->{category_label} cmp $b->{category_label} } @c_data;
    $param{category_loop} = \@c_data;
    $param{entry_id} = $entry_id;
    $param{saved} = $q->param('saved') ? 1 : 0;
    $app->build_page('edit_placements.tmpl', \%param);
}

sub save_placements {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    my $entry_id = $q->param('entry_id');
    my $blog_id = $q->param('blog_id');
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id);
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_edit_entry($entry, $app->{author});
    my @cat_ids = $q->param('category_id');
    require MT::Placement;
    my @place = MT::Placement->load({ entry_id => $entry_id,
                                      is_primary => 0 });
    for my $place (@place) {
        $place->remove;
    }
    for my $cat_id (@cat_ids) {
        ## Check for the stupid dummy option we have to add in order to
        ## get rid of the jumping select box on Mac IE.
        next if $cat_id == -1;

        my $place = MT::Placement->new;
        $place->entry_id($entry_id);
        $place->blog_id($blog_id);
        $place->is_primary(0);
        $place->category_id($cat_id);
        $place->save
            or return $app->error($app->translate(
                "Saving placement failed: [_1]", $place->errstr));
    }
    $app->redirect($app->uri . "?__mode=edit_placements&entry_id=$entry_id&" .
                   'blog_id=' . $blog_id . '&saved=1');
}

sub list_categories {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_edit_categories;
    require MT::Category;
    require MT::Placement;
    require MT::Author;
    require MT::Trackback;
    require MT::TBPing;
    my %param;
    my %authors;
    my @data;
    my $iter = MT::Category->load_iter({ blog_id => $q->param('blog_id') });
    my $cols = MT::Category->column_names;
    while (my $obj = $iter->()) {
        my $row = { };
        for my $col (@$cols) {
            $row->{'category_' . $col} = $obj->$col();
        }
        $row->{category_label} = encode_html($row->{category_label}, 1);
        $row->{category_entrycount} = MT::Placement->count({
            category_id => $obj->id });
        if (my $tb = MT::Trackback->load({ category_id => $obj->id })) {
            $row->{has_tb} = 1;
            $row->{category_tbcount} = MT::TBPing->count({
                tb_id => $tb->id });
        }
        my $aid = $obj->author_id;
        $authors{$aid} ||= MT::Author->load($aid);
        $row->{category_author} = $authors{$aid} ? $authors{$aid}->name : '';
        $row->{is_object} = 1;
        push @data, $row;
    }
    @data = sort { $a->{category_label} cmp $b->{category_label} } @data;
    for (1..5) {
        push @data, { category_id => 'new', category_label => '' };
    }
    $param{category_loop} = \@data;
    $param{saved} = $q->param('saved');
    $param{saved_deleted} = $q->param('saved_deleted');
    $app->build_page('edit_categories.tmpl', \%param);
}

sub save_categories {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_edit_categories;
    require MT::Category;
    my @new = $q->param('category-new');
    my $blog_id = $q->param('blog_id');
    for my $label (@new) {
        next unless $label;
        my $cat = MT::Category->new;
        $cat->blog_id($blog_id);
        $cat->label($label);
        $cat->author_id($app->{author}->id);
        $cat->save or
            return $app->error($app->translate(
                "Saving category failed: [_1]", $cat->errstr));
    }
    for my $p ($q->param) {
        my($id) = $p =~ /^category-(\d+)/;
        next unless $id;
        my $cat = MT::Category->load($id) or
            return $app->error($app->translate(
                "Unknown category ID '[_1]'", $id));
        $cat->label( $q->param($p) );
        $cat->save or
            return $app->error($app->translate(
                "Saving category failed: [_1]", $cat->errstr));
    }
    $app->redirect($app->uri . '?__mode=list_cat&blog_id=' . $blog_id .
                   '&saved=1');
}

sub cfg_prefs {
    my $q = $_[0]->{query};
    $q->param('_type', 'blog');
    $q->param('id', scalar $q->param('blog_id'));
    $_[0]->edit_object({ output => 'cfg_prefs.tmpl' });
}

sub cfg_archives {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate(
        "You do not have permission to configure the blog"))
        unless $perms->can_edit_config;
    require MT::Blog;
    require MT::TemplateMap;
    require MT::Template;
    my %params;
    my $blog_id = $q->param('blog_id');
    my $blog = MT::Blog->load($blog_id);
    my %at = map { $_ => 1 } split /\s*,\s*/, $blog->archive_type;
    my $iter = MT::Template->load_iter({ blog_id => $blog_id });
    my(%tmpl_name);
    while (my $tmpl = $iter->()) {
        my $type = $tmpl->type;
        next unless $type eq 'archive' || $type eq 'category' ||
                    $type eq 'individual';
        $tmpl_name{$tmpl->id} = $tmpl->name;
    }
    my %map;
    my $total_rows = 2;
    $iter = MT::TemplateMap->load_iter({ blog_id => $blog_id });
    while (my $map = $iter->()) {
        push @{ $map{ $map->archive_type } }, {
            map_id => $map->id,
            archive_type => $map->archive_type,
            map_template_id => $map->template_id,
            map_file_template => encode_html($map->file_template, 1),
            map_is_preferred => $map->is_preferred,
            map_template_name => $tmpl_name{ $map->template_id },
        };
        $total_rows++;
    }
    my @data;
    for my $at (qw( Individual Daily Weekly Monthly Category )) {
        $map{$at} = [] unless $map{$at};
        my @map = sort { $a->{map_template_name} cmp $b->{map_template_name} }
                  @{ $map{$at} };
        push @data, {
            archive_type_translated => $app->translate($at),
            archive_type => $at,
            template_map => \@map,
            map_count => (scalar @map) + 2,
            is_selected => $at{$at},
        };
    }
    my %param = ( archive_types => \@data );
    $param{saved} = 1 if $q->param('saved');
    $param{saved_deleted} = 1 if $q->param('saved_deleted');
    $param{saved_added} = 1 if $q->param('saved_added');
    $app->build_page('cfg_archives.tmpl', \%param);
}

sub cfg_archives_save {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate(
        "You do not have permission to configure the blog"))
        unless $perms->can_edit_config;
    my $q = $app->{query};
    require MT::TemplateMap;
    require MT::Blog;
    my $blog_id = $q->param('blog_id');
    my $blog = MT::Blog->load($blog_id);
    my @types = $q->param('archive_type');
    if (!@types) {
        $blog->archive_type_preferred('');
        $blog->archive_type('None');
    } else {
        $blog->archive_type(join ',', @types);
        if (!$blog->archive_type_preferred) {
            $blog->archive_type_preferred($types[0]);
        }
    }
    $blog->save
        or return $app->error($app->translate(
            "Saving blog failed: [_1]", $blog->errstr));
    my @p = $q->param;
    for my $p (@p) {
        if ($p =~ /^archive_tmpl_preferred_(\w+)$/) {
            my $at = $1;
            my $map_id = $q->param($p);
            my @all = MT::TemplateMap->load({ blog_id => $blog_id,
                                              archive_type => $at });
            for my $map (@all) {
                next if $map->id eq $map_id;
                $map->is_preferred(0);
                $map->save;
            }

            my $map = MT::TemplateMap->load($map_id);
            $map->is_preferred(1);
            $map->save;
        }
        elsif ($p =~ /^archive_file_tmpl_(\d+)$/) {
            my $map_id = $1;
            my $map = MT::TemplateMap->load($map_id);
            $map->file_template($q->param($p));
            $map->save;
        }
    }
    $app->redirect($app->uri . "?__mode=cfg_archives&blog_id=$blog_id&saved=1");
}

sub cfg_archives_add {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate(
        "You do not have permission to configure the blog"))
        unless $perms->can_edit_config;
    require MT::Template;
    my $blog_id = $q->param('blog_id');
    my $iter = MT::Template->load_iter({ blog_id => $blog_id });
    my(@tmpl);
    while (my $tmpl = $iter->()) {
        my $type = $tmpl->type;
        next unless $type eq 'archive' || $type eq 'category' ||
                    $type eq 'individual';
        push @tmpl, { template_id => $tmpl->id, template_name => $tmpl->name };
    }
    @tmpl = sort { $a->{template_name} cmp $b->{template_name} } @tmpl;
    $app->build_page('cfg_archives_add.tmpl', { templates => \@tmpl });
}

sub cfg_archives_do_add {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate(
        "You do not have permission to configure the blog"))
        unless $perms->can_edit_config;
    require MT::TemplateMap;
    my $blog_id = $q->param('blog_id');
    my $at = $q->param('archive_type');
    my $count = MT::TemplateMap->count({ blog_id => $blog_id,
                                         archive_type => $at });
    my $map = MT::TemplateMap->new;
    $map->is_preferred($count ? 0 : 1);
    $map->template_id(scalar $q->param('template_id'));
    $map->blog_id($blog_id);
    $map->archive_type($at);
    $map->save
        or return $app->error($app->translate(
            "Saving map failed: [_1]", $map->errstr));
    $app->build_page('reload_opener.tmpl', { url => $app->uri . '?__mode=cfg_archives&blog_id=' . $blog_id . '&saved_added=1' });
}

sub list_blogs {
    my $app = shift;
    my $q = $app->{query};
    require MT::Blog;
    require MT::Permission;
    require MT::Entry;
    require MT::Comment;
    my $author = $app->{author};
    my @perms = MT::Permission->load({ author_id => $author->id });
    my %perms = map { $_->blog_id => $_ } @perms;
    my @blogs = MT::Blog->load;
    my @data;
    my %param;
    my $i = 1;
    for my $blog (@blogs) {
        my $blog_id = $blog->id;
        my $perms = $perms{ $blog_id };
        next unless $perms && $perms->role_mask;
        $param{can_edit_authors} = 1 if $perms->can_edit_authors;
        my $row = { id => $blog->id, name => uc($blog->name),
                    description => $blog->description };
        $row->{is_odd} = $i++ % 2 ? 1 : 0;
        $row->{num_entries} = MT::Entry->count({ blog_id => $blog_id });
        $row->{num_comments} = MT::Comment->count({ blog_id => $blog_id });
        $row->{num_authors} = 0;
        my $iter = MT::Permission->load_iter({ blog_id => $blog_id });
        while (my $p = $iter->()) {
            $row->{num_authors}++ if $p->role_mask > 0;
        }
        $row->{can_delete} = $perms->can_edit_config;
        push @data, $row;
    }
    $param{blog_loop} = \@data;
    $param{can_create_blog} = $author->can_create_blog;
    $param{can_view_log} = $author->can_view_log;
    $param{saved_deleted} = $q->param('saved_deleted');
    $app->build_page('list_blog.tmpl', \%param);
}

sub preview_entry {
    my $app = shift;
    my $q = $app->{query};
    require MT::Entry;
    require MT::Builder;
    require MT::Template::Context;
    require MT::Blog;
    my $blog_id = $q->param('blog_id');
    my $blog = MT::Blog->load($blog_id);
    my $entry = MT::Entry->new;
    $entry->title($q->param('title'));
    ## Strip linefeed characters.
    for my $col (qw( text text_more )) {
        (my $val = $q->param($col) || '') =~  tr/\r//d;
        $entry->$col($val);
    }
    $entry->convert_breaks(scalar $q->param('convert_breaks'));
    my $ctx = MT::Template::Context->new;
    $ctx->stash('entry', $entry);
    $ctx->stash('blog', $blog);
    my $build = MT::Builder->new;
    my $preview_code = <<'HTML';
<p><b><$MTEntryTitle$></b></p>
<$MTEntryBody$>
<$MTEntryMore$>
HTML
    my $tokens = $build->compile($ctx, $preview_code)
        or return $app->error($app->translate(
            "Parse error: [_1]", $build->errstr));
    defined(my $html = $build->build($ctx, $tokens))
        or return $app->error($app->translate(
            "Build error: [_1]", $build->errstr));
    my %param = ( preview_body => $html );
    if (my $id = $q->param('id')) {
        $param{id} = $id;
    }
    $param{new_object} = $param{id} ? 0 : 1;
    my $cols = MT::Entry->column_names;
    my @data = ({ data_name => 'author_id', data_value => $app->{author}->id });
    for my $col (@$cols) {
        next if $col eq 'created_on' || $col eq 'created_by' ||
                $col eq 'modified_on' || $col eq 'modified_by';
        push @data, { data_name => $col,
            data_value => encode_html(scalar $q->param($col), 1) };
    }
    for my $date (qw( created_on_old created_on_manual )) {
        push @data, { data_name => $date,
                      data_value => scalar $q->param($date) };
    }
    $param{entry_loop} = \@data;
    $app->build_page('preview_entry.tmpl', \%param);
}

sub rebuild_confirm {
    my $app = shift;
    my $blog_id = $app->{query}->param('blog_id');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    my $at = $blog->archive_type || '';
    my(@at, @data);
    if ($at && $at ne 'None') {
        @at = split /,/, $at;
        @data = map { {
                   archive_type => $_,
                   archive_type_label => $app->translate($_),
                } } @at;
    }
    my $order = join ',', @at, 'index';
    require MT::Entry;
    my $total = MT::Entry->count({ blog_id => $blog_id });
    my %param = ( archive_type_loop => \@data,
                  build_order => $order,
                  build_next => 0,
                  total_entries => $total );
    if (my $tmpl_id = $app->{query}->param('tmpl_id')) {
        require MT::Template;
        my $tmpl = MT::Template->load($tmpl_id);
        $param{index_tmpl_id} = $tmpl->id;
        $param{index_tmpl_name} = $tmpl->name;
    }
    $app->build_page('rebuild_confirm.tmpl', \%param);
}

my %Limit_Multipliers = (
    Individual => 1,
    Daily => 2,
    Weekly => 5,
    Monthly => 10,
);

sub start_rebuild_pages {
    my $app = shift;
    my $q = $app->{query};
    my $type = $q->param('type');
    my $next = $q->param('next');
    my @order = split /,/, $type;
    my $type_name = $order[$next];
    my $total_entries = $q->param('total_entries');
    my %param = ( build_type => $type,
                  build_next => $next,
                  total_entries => $total_entries,
                  build_type_name => $type_name );
    if (my $mult = $Limit_Multipliers{$type_name}) {
        $param{offset} = 0;
        $param{limit} = $app->{cfg}->EntriesPerRebuild * $mult;
        $param{is_individual} = 1;
        $param{indiv_range} = "1 - " .
            ($param{limit} > $total_entries ? $total_entries : $param{limit});
    } elsif ($type_name =~ /^index-(\d+)$/) {
        my $tmpl_id = $1;
        require MT::Template;
        my $tmpl = MT::Template->load($tmpl_id);
        $param{build_type_name} = "index template '" . $tmpl->name . "'";
        $param{is_one_index} = 1;
    } elsif ($type_name =~ /^entry-(\d+)$/) {
        my $entry_id = $1;
        require MT::Entry;
        my $entry = MT::Entry->load($entry_id);
        $param{build_type_name} = "entry '" . $entry->title . "'";
        $param{is_entry} = 1;
        $param{entry_id} = $entry_id;
        $param{is_bm} = $q->param('is_bm');
        $param{is_new} = $q->param('is_new');
        $param{old_status} = $q->param('old_status');
    }
    $param{is_full_screen} = $param{is_entry} && !$param{is_bm};
    $app->build_page('rebuilding.tmpl', \%param);
}

sub rebuild_pages {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    require MT::Entry;
    require MT::Blog;
    my $q = $app->{query};
    my $blog_id = $q->param('blog_id');
    my $blog = MT::Blog->load($blog_id);
    my $order = $q->param('type');
    my @order = split /,/, $order;
    my $next = $q->param('next');
    my $done = 0;
    my $type = $order[$next];
    $next++;
    $done++ if $next >= @order;
    my($offset, $limit);
    my $total_entries = $q->param('total_entries');

    ## Tells MT::_rebuild_entry_archive_type to cache loaded templates so
    ## that each template is only loaded once.
    $app->{cache_templates} = 1;

    my($tmpl_saved);

    if ($type eq 'all') {
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_rebuild;
        $app->rebuild( BlogID => $blog_id )
            or return;
    } elsif ($type eq 'index') {
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_rebuild;
        $app->rebuild_indexes( BlogID => $blog_id ) or return;
    } elsif ($type =~ /^index-(\d+)$/) {
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_rebuild;
        my $tmpl_id = $1;
        require MT::Template;
        $tmpl_saved = MT::Template->load($tmpl_id);
        $app->rebuild_indexes( BlogID => $blog_id, Template => $tmpl_saved,
                               Force => 1 )
            or return;
        $order = "index template '" . $tmpl_saved->name . "'";
    } elsif ($type =~ /^entry-(\d+)$/) {
        my $entry_id = $1;
        require MT::Entry;
        my $entry = MT::Entry->load($entry_id);
        return $app->error("Permission denied.")
            unless $perms->can_edit_entry($entry, $app->{author});
        $app->rebuild_entry( Entry => $entry, BuildDependencies => 1 )
            or return;
        $order = "entry '" . $entry->title . "'";
    } elsif ($Limit_Multipliers{$type}) {
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_rebuild;
        $offset = $q->param('offset') || 0;
        $limit = $q->param('limit');
        if ($offset < $total_entries) {
            $app->rebuild( BlogID => $blog_id,
                           ArchiveType => $type,
                           NoIndexes => 1,
                           Offset => $offset,
                           Limit => $limit )
                or return;
            $offset += $limit;
        }
        if ($offset < $total_entries) {
            $done-- if $done;
            $next--;
        } else {
            $offset = 0;
        }
    } elsif ($type) {
        return $app->error($app->translate("Permission denied."))
            unless $perms->can_rebuild;
        $app->rebuild( BlogID => $blog_id,
                       ArchiveType => $type,
                       NoIndexes => 1 )
            or return;
    }
    unless ($done) {
        my $type_name = $order[$next];
        ## If we're moving on to the next rebuild step, recalculate the
        ## limit.
        if (defined($offset) && $offset == 0) {
            if (my $mult = $Limit_Multipliers{$type_name}) {
                $limit = $app->{cfg}->EntriesPerRebuild * $mult;
            }
        }
        my %param = ( build_type => $order, build_next => $next,
                      build_type_name => $type_name,
                      total_entries => $total_entries,
                      offset => $offset, limit => $limit,
                      is_bm => scalar $q->param('is_bm'),
                      entry_id => scalar $q->param('entry_id'),
                      is_new => scalar $q->param('is_new'),
                      old_status => scalar $q->param('old_status') );
        if ($Limit_Multipliers{$type_name}) {
            $param{is_individual} = 1;
            $param{indiv_range} = sprintf "%d - %d", $offset+1,
                $offset + $limit > $total_entries ? $total_entries :
                $offset + $limit;
        }
        $app->build_page('rebuilding.tmpl', \%param);
    } else {
        if ($q->param('entry_id')) {
            require MT::Entry;
            my $entry = MT::Entry->load(scalar $q->param('entry_id'));
            require MT::Blog;
            my $blog = MT::Blog->load($entry->blog_id);
            my $list = $app->needs_ping( Entry => $entry, Blog => $blog,
                OldStatus => scalar $q->param('old_status') );
            if ($entry->status == MT::Entry::RELEASE() && $list) {
                my @urls = map { { url => $_ } } @$list;
                $app->build_page('pinging.tmpl', { blog_id => $blog->id,
                    entry_id => $entry->id,
                    old_status => scalar $q->param('old_status'),
                    is_new => scalar $q->param('is_new'),
                    url_list => \@urls,
                    is_bm => scalar $q->param('is_bm') });
            } else {
                $app->_finish_rebuild_ping($entry, scalar $q->param('is_new'));
            }
        } else {
            my $all = $order =~ /,/;
            my $type = $order;
            my $is_one_index = $order =~ /index template/;
            my $is_entry = $order =~ /entry/;
            my %param = ( all => $all, type => $type,
                          is_one_index => $is_one_index,
                          is_entry => $is_entry );
            if ($is_one_index) {
                $param{tmpl_url} = $blog->site_url;
                $param{tmpl_url} .= '/' if $param{tmpl_url} !~ m!/$!;
                $param{tmpl_url} .= $tmpl_saved->outfile;
            }
            $app->build_page('rebuilt.tmpl', \%param);
        }
    }
}

sub send_pings {
    my $app = shift;
    my $q = $app->{query};
    require MT::Entry;
    require MT::Blog;
    my $blog = MT::Blog->load(scalar $q->param('blog_id'));
    my $entry = MT::Entry->load(scalar $q->param('entry_id'));
    ## MT::ping_and_save pings each of the necessary URLs, then processes
    ## the return value from MT::ping to update the list of URLs pinged
    ## and not successfully pinged. It returns the return value from
    ## MT::ping for further processing. If a fatal error occurs, it returns
    ## undef.
    my $results = $app->ping_and_save(Blog => $blog, Entry => $entry,
        OldStatus => scalar $q->param('old_status'))
        or return;
    my $has_errors = 0;
    for my $res (@$results) {
        $has_errors++, $app->log("Ping '$res->{url}' failed: $res->{error}")
            unless $res->{good};
    }
    $app->_finish_rebuild_ping($entry, scalar $q->param('is_new'), $has_errors);
}

sub edit_permissions {
    my $app = shift;
    my %param = $_[0] ? %{ $_[0] } : ();
    my $q = $app->{query};
    my $author = $app->{author};
    require MT::Permission;
    require MT::Blog;
    require MT::Author;
    my @auth_perms = MT::Permission->load({ author_id => $author->id });
    ## @auth_perms is a list of Permissions for this user. List the
    ## blogs for which user has can_edit_authors permissions.
    my $all_perms = MT::Permission->perms;
    my $author_id = $q->param('author_id');
    $param{edit_author_id} = $author_id;
    my $iter = MT::Author->load_iter;
    my @a_data;
    while (my $author = $iter->()) {
        push @a_data, { author_id => $author->id,
                        author_name => $author->name };
        if ($author_id && $author->id == $author_id) {
            $a_data[-1]{author_selected} = 1;
            $param{selected_author_name} = $author->name;
            $param{can_create_blog} = $author->can_create_blog;
            $param{can_view_log} = $author->can_view_log;
        }
    }
    $param{author_loop} = \@a_data;
    my(@data, @o_data);
    my $has_permission = 0;
    for my $perms (@auth_perms) {
        next unless $perms->can_edit_authors;
        $has_permission++;
        my $blog = MT::Blog->load($perms->blog_id);
        my $row = { blog_name => $blog->name, blog_id => $blog->id,
                    author_id => $author_id };
        if ($param{checked_blog_ids} && $param{checked_blog_ids}{$blog->id}) {
            $row->{is_checked} = 1;
        }
        my $p = MT::Permission->load({ blog_id => $blog->id,
                                       author_id => $author_id });
        if ($p && $p->role_mask) {
            my @p_data;
            for my $ref (@$all_perms) {
                my $meth = 'can_' . $ref->[1];
                push @p_data, { have_access => $p->$meth(),
                                prompt => $ref->[2],
                                blog_id => $blog->id,
                                author_id => $author_id,
                                mask => $ref->[0] };
            }
            my $break = @p_data % 2 ? int(@p_data / 2) + 1 : @p_data / 2;
            $row->{perm_loop1} = [ @p_data[0..$break-1] ];
            $row->{perm_loop2} = [ @p_data[$break..$#p_data] ];
            push @data, $row;
        } else {
            push @o_data, $row;
        }
    }
    return $app->error($app->translate("Permission denied."))
        unless $has_permission;
    $param{blog_loop} = \@data;
    $param{blog_no_access_loop} = \@o_data;
    $param{saved_add_to_blog} = $q->param('saved_add_to_blog');
    $param{saved} = $q->param('saved');
    $app->build_page('edit_permissions.tmpl', \%param);
}

sub save_permissions {
    my $app = shift;
    my $q = $app->{query};
    require MT::Author;
    my $my_author_id = $app->{author}->id;
    my $author_id = $q->param('author_id');
    my $author = MT::Author->load($author_id);
    $author->can_create_blog($q->param('can_create_blog') ? 1 : 0);
    $author->can_view_log($q->param('can_view_log') ? 1 : 0);
    $author->save;
    for my $p ($q->param) {
        if ($p =~ /^role_mask-(\d+)$/) {
            my($blog_id) = ($1);
            my $perms = MT::Permission->load({ author_id => $my_author_id,
                                               blog_id => $blog_id });
            return $app->error($app->translate("Permission denied."))
                unless $perms && $perms->can_edit_authors;
            my $pe = $my_author_id == $author_id ? $perms :
                MT::Permission->load({ author_id => $author_id,
                                       blog_id => $blog_id });
            if (!$pe) {
                $pe = MT::Permission->new;
                $pe->blog_id($blog_id);
                $pe->author_id($author_id);
            }
            my $mask = 0;
            for my $val ($q->param($p)) {
                $mask += $val;
            }
            $pe->role_mask($mask);
            $pe->save;
        }
    }
    my $url = $app->uri . '?__mode=edit_permissions&author_id=' . $author_id .
              '&saved=1';
    if (my $blog_id = $q->param('add_role_mask')) {
        my $pe = MT::Permission->load({ author_id => $author_id,
                                        blog_id => $blog_id });
        if (!$pe) {
            $pe = MT::Permission->new;
            $pe->blog_id($blog_id);
            $pe->author_id($author_id);
        }
        $pe->can_post(1);
        $pe->save;
        require MT::Blog;
        my $blog = MT::Blog->load($blog_id);
        $url .= '&saved_add_to_blog=' . $blog->name;
    }
    $app->redirect($url);
}

sub send_notify {
    my $app = shift;
    my $q = $app->{query};
    my $entry_id = $q->param('entry_id') or
        return $app->error($app->translate("No entry ID provided"));
    require MT::Entry;
    require MT::Blog;
    require MT::Util;
    my $entry = MT::Entry->load($entry_id) or
        return $app->error($app->translate("No such entry '[_1]'", $entry_id));
    my $blog = MT::Blog->load($entry->blog_id);
    my $author = $entry->author;
    return $app->error($app->translate(
        "No email address for author '[_1]'", $author->name))
        unless $author->email;
    my $body = '';
    my $cols = 72;
    my $name = $app->translate("[_1] Update: [_2]", $blog->name, $entry->title);
    my $fill_len = $cols - length($name) - 2;
    $fill_len++ if $fill_len % 2;
    $name = ('(' x ($fill_len/2)) . ' ' . $name . ' ' . (')' x ($fill_len/2));
    $body .= $name . "\n\n";
    my @ts = offset_time_list(time, $blog);
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d",
        $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
    my $date = format_ts('%x', $ts, $blog);
    my $fill_left = ' ' x int(($cols - length($date)) / 2);
    $body .= "$fill_left$date\n\n\n";
    $body .= ('-' x $cols) . "\n\n";
    require Text::Wrap;
    $Text::Wrap::columns = $cols;
    if ($q->param('send_excerpt')) {
        local $Text::Wrap::columns = $cols - 4;
        $body .= Text::Wrap::wrap("    ", "    ", $entry->get_excerpt) . "\n\n";
        $body .= ('-' x $cols) . "\n\n";
    }
    $body .= $entry->permalink . "\n\n";
    $body .= Text::Wrap::wrap('', '', $q->param('message')) . "\n\n";
    if ($q->param('send_body')) {
        $body .= ('-' x $cols) . "\n\n";
        $body .= Text::Wrap::wrap('', '', $entry->text) . "\n";
    }
    my $subj = $app->translate("[_1] Update: [_2]", $blog->name, $entry->title);
    $subj =~ s![\x80-\xFF]!!g;
    my %head = ( To => $author->email, From => $author->email,
                 Subject => $subj,
                 'Content-Transfer-Encoding' => '8bit' );
    my $charset = $app->{cfg}->PublishCharset || 'iso-8859-1';
    $head{'Content-Type'} = qq(text/plain; charset="$charset");
    require MT::Notification;
    my $iter = MT::Notification->load_iter({ blog_id => $blog->id });
    my $i = 1;
    require MT::Mail;
    MT::Mail->send(\%head, $body)
        or return $app->error($app->translate(
            "Error sending mail ([_1]); try another MailTransfer setting?",
            MT::Mail->errstr));
    delete $head{To};
    while (my $note = $iter->()) {
        next unless $note->email;
        push @{ $head{Bcc} }, $note->email;
        if ($i++ % 20 == 0) {
            MT::Mail->send(\%head, $body) or
                return $app->error($app->translate(
                 "Error sending mail ([_1]); try another MailTransfer setting?",
                 MT::Mail->errstr));
            @{ $head{Bcc} } = ();
        }
    }
    if ($head{Bcc} && @{ $head{Bcc} }) {
        MT::Mail->send(\%head, $body)
            or return $app->error($app->translate(
             "Error sending mail ([_1]); try another MailTransfer setting?",
             MT::Mail->errstr));
    }
    $app->redirect($app->uri . '?__mode=view&_type=entry&blog_id=' .
        $entry->blog_id . '&id=' . $entry->id . '&saved_notify=1');
}

sub start_upload {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_upload;
    my $blog_id = $app->{query}->param('blog_id');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    $app->build_page('upload.tmpl', {
        local_archive_path => $blog->archive_path,
        local_site_path => $blog->site_path,
    });
}

sub upload_file {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_upload;
    my $q = $app->{query};
    my($fh, $no_upload);
    if ($ENV{MOD_PERL}) {
        my $up = $q->upload('file');
        $no_upload = !$up || !$up->size;
        $fh = $up->fh if $up;
    } else {
        ## Older versions of CGI.pm didn't have an 'upload' method.
        eval { $fh = $q->upload('file') };
        if ($@ && $@ =~ /^Undefined subroutine/) {
            $fh = $q->param('file');
        }
        $no_upload = !$fh;
    }
    my $has_overwrite = $q->param('overwrite_yes') || $q->param('overwrite_no');
    return $app->error($app->translate("You did not choose a file to upload."))
        if $no_upload && !$has_overwrite;
    my $fname = $q->param('file') || $q->param('fname');
    $fname =~ s!\\!/!g;   ## Change backslashes to forward slashes
    $fname =~ s!^.*/!!;   ## Get rid of full directory paths
    if ($fname =~ m!\.\.|\0|\|!) {
        return $app->error($app->translate("Invalid filename '[_1]'", $fname));
    }
    my $blog_id = $q->param('blog_id');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    my $fmgr = $blog->file_mgr;

    ## Set up the full path to the local file; this path could start
    ## at either the Local Site Path or Local Archive Path, and could
    ## include an extra directory or two in the middle.
    my($base, $extra_path);
    if ($q->param('site_path')) {
        $base = $blog->site_path;
        $extra_path = $q->param('extra_path_site');
    } else {
        $base = $blog->archive_path;
        $extra_path = $q->param('extra_path_archive');
    }
    my $extra_path_save = $extra_path;
    my $path = $base;
    if ($extra_path) {
        if ($extra_path =~ m!\.\.|\0|\|!) {
            return $app->error($app->translate(
                "Invalid extra path '[_1]'", $extra_path));
        }
        $path = File::Spec->catdir($path, $extra_path);
        ## Untaint. We already checked for security holes in $extra_path.
        ($path) = $path =~ /(.+)/s;
        ## Build out the directory structure if it doesn't exist. DirUmask
        ## determines the permissions of the new directories.
        unless ($fmgr->exists($path)) {
            $fmgr->mkpath($path)
                or return $app->error($app->translate(
                    "Can't make path '[_1]': [_2]", $path, $fmgr->errstr));
        }
    }
    $extra_path = File::Spec->catfile($extra_path, $fname);
    my $local_file = File::Spec->catfile($path, $fname);

    ## Untaint. We have already tested $fname and $extra_path for security
    ## issues above, and we have to assume that we can trust the user's
    ## Local Archive Path setting. So we should be safe.
    ($local_file) = $local_file =~ /(.+)/s;

    ## If $local_file already exists, we try to write the upload to a
    ## tempfile, then ask for confirmation of the upload.
    if ($fmgr->exists($local_file)) {
        if ($has_overwrite) {
            my $tmp = $q->param('temp');
            if ($tmp =~ m!([^/]+)$!) {
                $tmp = $1;
            } else {
                return $app->error($app->translate(
                    "Invalid temp file name '[_1]'", $tmp));
            }
            my $tmp_file = File::Spec->catfile($app->{cfg}->TempDir, $tmp);
            if ($q->param('overwrite_yes')) {
                $fh = gensym();
                open $fh, $tmp_file
                    or return $app->error($app->translate(
                        "Error opening '[_1]': [_2]", $tmp_file, "$!"));
            } else {
                if (-e $tmp_file) {
                    unlink($tmp_file)
                        or return $app->error($app->translate(
                            "Error deleting '[_1]': [_2]", $tmp_file, "$!"));
                }
                return $app->start_upload;
            }
        } else {
            eval { require File::Temp };
            if ($@) {
                return $app->error($app->translate(
                    "File with name '[_1]' already exists. (Install " .
                    "File::Temp if you'd like to be able to overwrite " .
                    "existing uploaded files.)", $fname));
            }
            my($tmp_fh, $tmp_file) =
                File::Temp::tempfile(DIR => $app->{cfg}->TempDir);
            defined(_write_upload($fh, $tmp_fh))
                or return $app->error($app->translate(
                    "File with name '[_1]' already exists; Tried to write " .
                    "to tempfile, but open failed: [_2]", $fname, "$!"));
            my($vol, $path, $tmp) = File::Spec->splitpath($tmp_file);
            return $app->build_page('upload_confirm.tmpl', {
                temp => $tmp, extra_path => $extra_path_save,
                site_path => scalar $q->param('site_path'),
                fname => $fname });
        }
    }

    ## File does not exist, or else we have confirmed that we can overwrite.
    my $umask = oct $app->{cfg}->UploadUmask;
    my $old = umask($umask);
    defined(my $bytes = $fmgr->put($fh, $local_file, 'upload'))
        or return $app->error($app->translate(
            "Error writing upload to '[_1]': [_2]", $local_file,
            $fmgr->errstr));
    umask($old);

    ## Use Image::Size to check if the uploaded file is an image, and if so,
    ## record additional image info (width, height). We first rewind the
    ## filehandle $fh, then pass it in to imgsize.
    seek $fh, 0, 0;
    eval { require Image::Size; };
    return $app->error($app->translate(
        "Perl module Image::Size is required to determine " .
        "width and height of uploaded images.")) if $@;
    my($w, $h, $id) = Image::Size::imgsize($fh);

    ## Close up the filehandle.
    close $fh;

    ## If we are overwriting the file, that means we still have a temp file
    ## lying around. Delete it.
    if ($q->param('overwrite_yes')) {
        my $tmp = $q->param('temp');
        if ($tmp =~ m!([^/]+)$!) {
            $tmp = $1;
        } else {
            return $app->error($app->translate(
                "Invalid temp file name '[_1]'", $tmp));
        }
        my $tmp_file = File::Spec->catfile($app->{cfg}->TempDir, $tmp);
        unlink($tmp_file)
            or return $app->error($app->translate(
                "Error deleting '[_1]': [_2]", $tmp_file, "$!"));
    }

    ## We are going to use $extra_path as the filename and as the url passed
    ## in to the templates. So, we want to replace all of the '\' characters
    ## with '/' characters so that it won't look like backslashed characters.
    ## Also, get rid of a slash at the front, if present.
    $extra_path =~ s!\\!/!g;
    $extra_path =~ s!^/!!;
    my %param = ( width => $w, height => $h, bytes => $bytes,
                  image_type => $id, fname => $extra_path,
                  site_path => scalar $q->param('site_path') );
    my $url = $q->param('site_path') ? $blog->site_url : $blog->archive_url;
    $url .= '/' unless $url =~ m!/$!;
    $extra_path =~ s!^/!!;
    $url .= $extra_path;
    $param{url} = $url;
    $param{is_image} = defined($w) && defined($h);
    if ($param{is_image}) {
        eval { require MT::Image; MT::Image->new or die; };
        $param{do_thumb} = !$@ ? 1 : 0;
    }
    $app->build_page('upload_complete.tmpl', \%param);
}

sub _write_upload {
    my($upload_fh, $dest_fh) = @_;
    my $fh = gensym();
    if (ref($dest_fh) eq 'GLOB') {
        $fh = $dest_fh;
    } else {
        open $fh, ">$dest_fh" or return;
    }
    binmode $fh;
    binmode $upload_fh;
    my($bytes, $data) = (0);
    while (my $len = read $upload_fh, $data, 8192) {
        print $fh $data;
        $bytes += $len;
    }
    close $fh;
    $bytes;
}

sub start_search_replace {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_post;
    $app->build_page('search_replace.tmpl',
        { search_cols_title => 1, search_cols_text => 1,
          search_cols_text_more => 1, search_cols_keywords => 1, });
}

sub search_replace {
    my $app = shift;
    my $q = $app->{query};
    my $blog_id = $q->param('blog_id');
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    my($search, $replace, $do_replace, $case, $is_regex) =
        map scalar $q->param($_), qw( search replace do_replace case is_regex );
    my @cols = $q->param('search_cols');
    ## Sometimes we need to pass in the search columns like 'title,text', so
    ## we look for a comma (not a valid character in a column name) and split
    ## on it if it's there.
    if ($cols[0] =~ /,/) {
        @cols = split /,/, $cols[0];
    }
    unless ($is_regex) {
        $search = quotemeta($search);
        $search = '(?i)' . $search unless $case;
    }
    require MT::Entry;
    my $iter = MT::Entry->load_iter({ blog_id => $blog_id },
        { 'sort' => 'created_on', direction => 'descend' });
    my @data;
    my $i = 1;
    my @to_save;
    my $author_id = $app->{author}->id;
    while (my $entry = $iter->()) {
        next unless $perms->can_edit_entry($entry, $app->{author});
        my $match = 0;
        for my $col (@cols) {
            my $text = $entry->$col();
            $text = '' unless defined $text;
            if ($do_replace) {
                $match++ if $text =~ s!$search!$replace!go;
                $entry->$col($text);
            } else {
                $match = $text =~ m!$search!o;
                last if $match;
            }
        }
        if ($match && $do_replace) {
            push @to_save, $entry;
        }
        if ($match) {
            my $title = $entry->title;
            unless ($title) {
                $title = remove_html($entry->text);
                $title = substr($title, 0, 22) . '...';
            }
            push @data, { entry_title => encode_html($title, 1),
                          entry_id => $entry->id,
                          entry_created_on =>
                              format_ts("%Y.%m.%d", $entry->created_on),
                          is_odd => $i++ % 2 ? 1 : 0,
            };
        }
    }
    for my $entry (@to_save) {
        $entry->save
            or return $app->error($app->translate(
                "Saving entry failed: [_2]", $entry->errstr));
    }
    my %res = (
        have_results => 1,
        results => \@data,
        search => scalar $q->param('search'),
        replace => $replace,
        do_replace => $do_replace,
        case => $case,
        is_regex => $is_regex
    );
    for my $col (@cols) {
        $res{'search_cols_' . $col} = 1;
    }
    $app->build_page('search_replace.tmpl', \%res);
}

sub export {
    my $app = shift;
    $app->{no_print_body} = 1;

    local $| = 1;
    $app->send_http_header('text/plain');

    require MT::Entry;
    require MT::Permission;

    my $q = $app->{query};
    my $SEP = ('-' x 8);
    my $SUB_SEP = ('-' x 5);

    require MT::Blog;
    my $blog_id = $q->param('blog_id')
        or return $app->error($app->translate("No blog ID"));
    my $blog = MT::Blog->load($blog_id)
        or return $app->error($app->translate(
            "Load of blog '[_1]' failed: [_2]", $blog_id, MT::Blog->errstr));
    $blog->language('en');

    my $author_id = $app->{author}->id;
    my $perms = MT::Permission->load({ author_id => $author_id,
                                       blog_id => $blog_id });
    return $app->error($app->translate("You do not have export permissions"))
        unless $perms && $perms->can_edit_config;

    ## Create template for exporting a single entry
    require MT::Template;
    require MT::Template::Context;
    my $tmpl = MT::Template->new;
    $tmpl->blog_id($blog_id);
    $tmpl->name('Export Template');
    $tmpl->text(<<'TEXT');
AUTHOR: <$MTEntryAuthor$>
TITLE: <$MTEntryTitle$>
STATUS: <$MTEntryStatus$>
ALLOW COMMENTS: <$MTEntryFlag flag="allow_comments"$>
CONVERT BREAKS: <$MTEntryFlag flag="convert_breaks"$>
ALLOW PINGS: <$MTEntryFlag flag="allow_pings"$>
PRIMARY CATEGORY: <$MTEntryCategory$>
<MTEntryCategories>
CATEGORY: <$MTCategoryLabel$>
</MTEntryCategories>
DATE: <$MTEntryDate format="%m/%d/%Y %I:%M:%S %p"$>
-----
BODY:
<$MTEntryBody convert_breaks="0"$>
-----
EXTENDED BODY:
<$MTEntryMore convert_breaks="0"$>
-----
EXCERPT:
<$MTEntryExcerpt no_generate="1" convert_breaks="0"$>
-----
KEYWORDS:
<$MTEntryKeywords$>
-----
<MTComments>
COMMENT:
AUTHOR: <$MTCommentAuthor$>
EMAIL: <$MTCommentEmail$>
IP: <$MTCommentIP$>
URL: <$MTCommentURL$>
DATE: <$MTCommentDate format="%m/%d/%Y %I:%M:%S %p"$>
<$MTCommentBody convert_breaks="0"$>
-----
</MTComments>
<MTPings>
PING:
TITLE: <$MTPingTitle$>
URL: <$MTPingURL$>
IP: <$MTPingIP$>
BLOG NAME: <$MTPingBlogName$>
DATE: <$MTPingDate format="%m/%d/%Y %I:%M:%S %p"$>
<$MTPingExcerpt$>
-----
</MTPings>
--------
TEXT

    my $iter = MT::Entry->load_iter({ blog_id => $blog_id },
        { 'sort' => 'created_on', direction => 'ascend' });

    while (my $entry = $iter->()) {
        my $ctx = MT::Template::Context->new;
        $ctx->stash('entry', $entry);
        $ctx->{current_timestamp} = $entry->created_on;
        my $res = $tmpl->build($ctx)
            or return $app->error($app->translate(
                "Export failed on entry '[_1]': [_2]", $entry->title,
                $tmpl->errstr));
        $app->print($res);
    }
    1;
}

sub do_import {
    my $app = shift;
    $app->{no_print_body} = 1;

    local $| = 1;
    $app->send_http_header('text/html');
    $app->print("<pre>\n");

    require MT::Entry;
    require MT::Placement;
    require MT::Category;
    require MT::Author;
    require MT::Permission;

    my $q = $app->{query};
    my $SEP = ('-' x 8);
    my $SUB_SEP = ('-' x 5);

    my(%authors, %categories);
    require MT::Blog;
    my $blog_id = $q->param('blog_id')
        or return $app->error($app->translate("No blog ID"));
    my $blog = MT::Blog->load($blog_id)
        or return $app->error($app->translate(
            "Load of blog '[_1]' failed: [_2]", $blog_id, MT::Blog->errstr));

    ## Determine the author as whom we will import the entries.
    my $author = $app->{author};
    my $author_id = $author->id;
    my $perms = MT::Permission->load({ author_id => $author_id,
                                       blog_id => $blog_id });
    return $app->error($app->translate("You do not have import permissions"))
        unless $perms && $perms->can_edit_config;
    $app->print("Importing entries into blog '", $blog->name, "'\n");
    my($pass);
    my $import_as_me = $q->param('import_as_me');
    if ($import_as_me) {
        $app->print("Importing entries as author '", $author->name, "'\n");
    } else {
        $pass = $q->param('password')
            or return $app->error($app->translate(
                "You need to provide a password if you are going to\n" .
                "create new authors for each author listed in your blog.\n"));
        $app->print("Creating new authors for each author found in the blog\n");
    }
    $app->print("\n");

    ## Default category for imported entries.
    my $def_cat_id = $q->param('default_cat_id');

    my $t_start = $q->param('title_start');
    my $t_end = $q->param('title_end');
    my $allow_comments = $blog->allow_comments_default;
    my $allow_pings = $blog->allow_pings_default ? 1 : 0;
    my $convert_breaks = $blog->convert_paras;
    my $def_status = $q->param('default_status') || $blog->status_default;

    my $dir = $app->{cfg}->ImportPath;
    opendir DH, $dir or return $app->error($app->translate(
        "Can't open directory '[_1]': [_2]", $dir, "$!"));
    for my $f (readdir DH) {
        next if $f =~ /^\./;
        $app->print("Importing entries from file '$f'\n");
        my $file = File::Spec->catfile($dir, $f);
        open FH, $file
            or return $app->error($app->translate(
                "Can't open file '[_1]': [_2]", $file, "$!"));
        local $/ = $SEP;
        ENTRY_BLOCK:
        while (<FH>) {
            my($meta, @pieces) = split /$SUB_SEP/;
            next unless $meta && @pieces;

            ## Create entry object and assign some defaults.
            my $entry = MT::Entry->new;
            $entry->blog_id($blog_id);
            $entry->status($def_status);
            $entry->allow_comments($allow_comments);
            $entry->allow_pings($allow_pings);
            $entry->convert_breaks($convert_breaks);
            $entry->author_id($author_id) if $import_as_me;

            ## Some users may want to import just their GM comments, having
            ## already imported their GM entries. We try to match up the
            ## entries using the created on timestamp, and the import file
            ## tells us not to import an entry with the meta-tag "NO ENTRY".
            my $no_save = 0;

            ## Handle all meta-data: author, category, title, date.
            my $i = -1;
            my($primary_cat_id, @placements);
            my @lines = split /\r?\n/, $meta;
            META:
            for my $line (@lines) {
                $i++;
                next unless $line;
                $line =~ s!^\s*!!;
                $line =~ s!\s*$!!;
                my($key, $val) = split /\s*:\s*/, $line, 2;
                if ($key eq 'AUTHOR' && !$import_as_me) {
                    my $author;
                    unless ($author = $authors{$val}) {
                        $author = MT::Author->load({ name => $val });
                    }
                    unless ($author) {
                        $author = MT::Author->new;
                        $author->created_by($author_id);
                        $author->name($val);
                        $author->email('');
                        $author->set_password($pass);
                        $app->print("Creating new author ('$val')...");
                        if ($author->save) {
                            $app->print("ok\n");
                        } else {
                            $app->print("failed\n");
                            return $app->error($app->translate(
                                "Saving author failed: [_1]", $author->errstr));
                        }
                        $authors{$val} = $author;
                        $app->print("Assigning permissions for new author...");
                        my $perms = MT::Permission->new;
                        $perms->blog_id($blog_id);
                        $perms->author_id($author->id);
                        $perms->can_post(1);
                        if ($perms->save) {
                            $app->print("ok\n");
                        } else {
                            $app->print("failed\n");
                            return $app->error($app->translate(
                             "Saving permission failed: [_1]", $perms->errstr));
                        }
                    }
                    $entry->author_id($author->id);
                } elsif ($key eq 'CATEGORY' || $key eq 'PRIMARY CATEGORY') {
                    if ($val) {
                        my $cat;
                        unless ($cat = $categories{$val}) {
                            $cat = MT::Category->load({ label => $val,
                                                        blog_id => $blog_id });
                        }
                        unless ($cat) {
                            $cat = MT::Category->new;
                            $cat->blog_id($blog_id);
                            $cat->label($val);
                            $cat->author_id($entry->author_id);
                            $app->print("Creating new category ('$val')...");
                            if ($cat->save) {
                                $app->print("ok\n");
                            } else {
                                $app->print("failed\n");
                                return $app->error($app->translate(
                                 "Saving category failed: [_1]", $cat->errstr));
                            }
                            $categories{$val} = $cat;
                        }
                        if ($key eq 'CATEGORY') {
                            push @placements, $cat->id;
                        } else {
                            $primary_cat_id = $cat->id;
                        }
                    }
                } elsif ($key eq 'TITLE') {
                    $entry->title($val);
                } elsif ($key eq 'DATE') {
                    my $date = $app->_convert_date($val) or return;
                    $entry->created_on($date);
                } elsif ($key eq 'STATUS') {
                    my $status = MT::Entry::status_int($val)
                        or return $app->error($app->translate(
                            "Invalid status value '[_1]'", $val));
                    $entry->status($status);
                } elsif ($key eq 'ALLOW COMMENTS') {
                    $val = 0 unless $val;
                    $entry->allow_comments($val);
                } elsif ($key eq 'CONVERT BREAKS') {
                    $val = 0 unless $val;
                    $entry->convert_breaks($val);
                } elsif ($key eq 'ALLOW PINGS') {
                    $val = 0 unless $val;
                    return $app->error("Invalid allow pings value '$val'")
                        unless $val eq 0 || $val eq 1;
                    $entry->allow_pings($val);
                } elsif ($key eq 'NO ENTRY') {
                    $no_save++;
                } elsif ($key eq 'START BODY') {
                    ## Special case for backwards-compatibility with old
                    ## export files: if we see START BODY: on a line, we
                    ## gather up the rest of the lines in meta and package
                    ## them for handling below in the non-meta area.
                    @pieces = ("BODY:\n" . join "\n", @lines[$i+1..$#lines]);
                    last META;
                }
            }

            ## If we're not saving this entry (but rather just using it to
            ## import comments, for example), we need to load the relevant
            ## entry using the timestamp.
            if ($no_save) {
                my $ts = $entry->created_on;
                $entry = MT::Entry->load({ created_on => $ts,
                    blog_id => $blog_id });
                if (!$entry) {
                    $app->print("Can't find existing entry with timestamp " .
                        "'$ts'... skipping comments, and moving on to " .
                        "next entry.\n");
                    next ENTRY_BLOCK;
                } else {
                    $app->print(sprintf "Importing into existing " .
                        "entry %d ('%s')\n", $entry->id, $entry->title);
                }
            }

            ## Deal with non-meta pieces: entry body, extended entry body,
            ## comments. We need to hold the list of comments until after
            ## we have saved the entry, then assign the new entry ID of
            ## the entry to each comment.
            my(@comments, @pings);
            for my $piece (@pieces) {
                $piece =~ s!^\s*!!;
                $piece =~ s!\s*$!!;
                if ($piece =~ s/^BODY:\r?\n//) {
                    $entry->text($piece);
                }
                elsif ($piece =~ s/^EXTENDED BODY:\r?\n//) {
                    $entry->text_more($piece);
                }
                elsif ($piece =~ s/^EXCERPT:\r?\n//) {
                    $entry->excerpt($piece) if $piece =~ /\S/;
                }
                elsif ($piece =~ s/^KEYWORDS:\r?\n//) {
                    $entry->keywords($piece) if $piece =~ /\S/;
                }
                elsif ($piece =~ s/^COMMENT:\r?\n//) {
                    ## Comments are: AUTHOR, EMAIL, URL, IP, DATE (in any order),
                    ## then body
                    my $comment = MT::Comment->new;
                    $comment->blog_id($blog_id);
                    my @lines = split /\r?\n/, $piece;
                    my($i, $body_idx) = (0) x 2;
                    COMMENT:
                    for my $line (@lines) {
                        $line =~ s!^\s*!!;
                        my($key, $val) = split /\s*:\s*/, $line, 2;
                        if ($key eq 'AUTHOR') {
                            $comment->author($val);
                        } elsif ($key eq 'EMAIL') {
                            $comment->email($val);
                        } elsif ($key eq 'URL') {
                            $comment->url($val);
                        } elsif ($key eq 'IP') {
                            $comment->ip($val);
                        } elsif ($key eq 'DATE') {
                            my $date = $app->_convert_date($val) or return;
                            $comment->created_on($date);
                        } else {
                            ## Now we have reached the body of the comment;
                            ## everything from here until the end of the
                            ## array is body.
                            $body_idx = $i;
                            last COMMENT;
                        }
                        $i++;
                    }
                    $comment->text( join "\n", @lines[$body_idx..$#lines] );
                    push @comments, $comment;
                }
                elsif ($piece =~ s/^PING:\r?\n//) {
                    ## Pings are: TITLE, URL, IP, DATE, BLOG NAME,
                    ## then excerpt
                    require MT::TBPing;
                    my $ping = MT::TBPing->new;
                    $ping->blog_id($blog_id);
                    my @lines = split /\r?\n/, $piece;
                    my($i, $body_idx) = (0) x 2;
                    PING:
                    for my $line (@lines) {
                        $line =~ s!^\s*!!;
                        my($key, $val) = split /\s*:\s*/, $line, 2;
                        if ($key eq 'TITLE') {
                            $ping->title($val);
                        } elsif ($key eq 'URL') {
                            $ping->source_url($val);
                        } elsif ($key eq 'IP') {
                            $ping->ip($val);
                        } elsif ($key eq 'DATE') {
                            my $date = $app->_convert_date($val) or return;
                            $ping->created_on($date);
                        } elsif ($key eq 'BLOG NAME') {
                            $ping->blog_name($val);
                        } else {
                            ## Now we have reached the ping excerpt;
                            ## everything from here until the end of the
                            ## array is body.
                            $body_idx = $i;
                            last PING;
                        }
                        $i++;
                    }
                    $ping->excerpt( join "\n", @lines[$body_idx..$#lines] );
                    push @pings, $ping;
                }
            }

            ## Assign a title if one is not already assigned.
            unless ($entry->title) {
                my $body = $entry->text;
                if ($t_start && $t_end && $body =~
                    s!\Q$t_start\E(.*?)\Q$t_end\E\s*!!s) {
                    (my $title = $1) =~ s/[\r\n]/ /g;
                    $entry->title($title);
                    $entry->text($body);
                } else {
                    $entry->title( MT::Util::first_n_words($body, 5) );
                }
            }

            ## If an entry has comments listed along with it, set
            ## allow_comments to 1 no matter what the default is.
            if (@comments && !$entry->allow_comments) {
                $entry->allow_comments(1);
            }

            ## If an entry has TrackBack pings listed along with it,
            ## set allow_pings to 1 no matter what the default is.
            if (@pings) {
                $entry->allow_pings(1);

                ## If the entry has TrackBack pings, we need to make sure
                ## that an MT::Trackback object is created. To do that, we
                ## need to make sure that $entry->save is called.
                $no_save = 0;
            }

            ## Save entry.
            unless ($no_save) {
                $app->print("Saving entry ('", $entry->title, "')... ");
                if ($entry->save) {
                    $app->print("ok (ID ", $entry->id, ")\n");
                } else {
                    $app->print("failed\n");
                    return $app->error($app->translate(
                        "Saving entry failed: [_1]", $entry->errstr));
                }
            }

            ## Save placement.
            ## If we have no primary category ID (from a PRIMARY CATEGORY
            ## key), we first look to see if we have any placements from
            ## CATEGORY tags. If so, we grab the first one and use it as the
            ## primary placement. If not, we try to use the default category
            ## ID specified.
            if (!$primary_cat_id) {
                if (@placements) {
                    $primary_cat_id = shift @placements;
                } elsif ($def_cat_id) {
                    $primary_cat_id = $def_cat_id;
                }
            } else {
                ## If a PRIMARY CATEGORY is also specified as a CATEGORY, we
                ## don't want to add it twice; so we filter it out.
                @placements = grep { $_ != $primary_cat_id } @placements;
            }

            ## So if we have a primary placement from any of the means
            ## specified above, we add the placement.
            if ($primary_cat_id) {
                my $place = MT::Placement->new;
                $place->is_primary(1);
                $place->entry_id($entry->id);
                $place->blog_id($blog_id);
                $place->category_id($primary_cat_id);
                $place->save
                    or return $app->error($app->translate(
                        "Saving placement failed: [_1]", $place->errstr));
            }

            ## Now add all of the other, non-primary placements.
            for my $cat_id (@placements) {
                my $place = MT::Placement->new;
                $place->is_primary(0);
                $place->entry_id($entry->id);
                $place->blog_id($blog_id);
                $place->category_id($cat_id);
                $place->save
                    or return $app->error($app->translate(
                        "Saving placement failed: [_1]", $place->errstr));
            }

            ## Save comments.
            for my $comment (@comments) {
                $comment->entry_id($entry->id);
                $app->print("Creating new comment ('", $comment->author, 
                    "')... ");
                if ($comment->save) {
                    $app->print("ok (ID ", $comment->id, ")\n");
                } else {
                    $app->print("failed\n");
                    return $app->error($app->translate(
                        "Saving comment failed: [_1]", $comment->errstr));
                }
            }

            ## Save pings.
            if (@pings) {
                my $tb = MT::Trackback->load({ entry_id => $entry->id })
                    or return $app->error($app->translate(
                        "Entry has no MT::Trackback object!"));
                for my $ping (@pings) {
                    $ping->tb_id($tb->id);
                    $app->print("Creating new ping ('", $ping->title,
                    "')... ");
                    if ($ping->save) {
                        $app->print("ok (ID ", $ping->id, ")\n");
                    } else {
                        $app->print("failed\n");
                        return $app->error($app->translate(
                            "Saving ping failed: [_1]", $ping->errstr));
                    }
                }
            }
        }
    }
    closedir DH;

    $app->print(<<TEXT);

All data imported successfully! Make sure that you remove
the files that you imported from the 'import' folder, so that
if/when you run the import process again, those files will not
be re-imported.
</pre>
TEXT
    1;
}

sub _convert_date {
    my $app = shift;
    my($date) = @_;
    my($mo, $d, $y, $h, $m, $s, $ampm) = $date =~
        m!^(\d{1,2})/(\d{1,2})/(\d{2,4}) (\d{1,2}):(\d{1,2}):(\d{1,2})(?:\s(\w{2}))?$!
        or return $app->error($app->translate(
            "Invalid date format '[_1]'; must be " .
            "'MM/DD/YYYY HH:MM:SS AM|PM' (AM|PM is optional)", $date));
    if ($ampm) {
        if ($ampm eq 'PM' && $h < 12) {
            $h += 12;
        } elsif ($ampm eq 'AM' && $h == 12) {
            $h = 0;
        }
    }
    if (length($y) == 2) {
        $y += 1900;
    }
    sprintf "%04d%02d%02d%02d%02d%02d", $y, $mo, $d, $h, $m, $s;
}

sub show_entry_prefs {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    my %param;
    my $prefs = $perms->entry_prefs || 'Advanced|Bottom';
    ($prefs, my($pos)) = split /\|/, $prefs;
    if ($prefs eq 'Basic' || $prefs eq 'Advanced') {
        $param{'disp_prefs_' . $prefs} = 1;
    } else {
        $param{disp_prefs_custom} = 1;
        my @p = split /,/, $prefs;
        for my $p (@p) {
            $param{'disp_prefs_show_' . $p} = 1;
        }
    }
    $param{'position_' . $pos} = 1;
    $param{entry_id} = $app->{query}->param('entry_id');
    $app->build_page('entry_prefs.tmpl', \%param);
}

sub save_entry_prefs {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    my $q = $app->{query};
    my $type = $q->param('entry_prefs');
    my $prefs;
    if ($type eq 'Custom') {
        $prefs = join ',', $q->param('custom_prefs');
    } else {
        $prefs = $type;
    }
    $prefs .= '|' . $q->param('bar_position');
    $perms->entry_prefs($prefs);
    $perms->save
        or return $app->error($app->translate(
            "Saving permissions failed: [_1]", $perms->errstr));
    my $url = $app->uri . '?__mode=view&_type=entry';
    if (my $id = $q->param('entry_id')) {
        $url .= '&id=' . $id;
    }
    $url .= '&blog_id=' . $perms->blog_id . '&saved_prefs=1';
    $app->build_page('reload_opener.tmpl', { url => $url });
}

sub pinged_urls {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    my %param;
    my $entry_id = $app->{query}->param('entry_id');
    require MT::Entry;
    my $entry = MT::Entry->load($entry_id);
    $param{url_loop} = [ map { { url => $_ } } @{ $entry->pinged_url_list } ];
    $app->build_page('pinged_urls.tmpl', \%param);
}

sub tb_cat_pings {
    my $app = shift;
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_edit_categories;
    require MT::Category;
    my $q = $app->{query};
    my $cat = MT::Category->load(scalar $q->param('category_id'));

    require MT::Trackback;
    require MT::TBPing;
    my $tb = MT::Trackback->load({ category_id => $cat->id });
    my @tb_data;
    if ($tb) {
        my $iter = MT::TBPing->load_iter({ tb_id => $tb->id },
                        { 'sort' => 'created_on',
                          direction => 'ascend' });
        my $i = 1;
        while (my $ping = $iter->()) {
            my $df = format_ts("%Y-%m-%d %H:%M:%S", $ping->created_on);
            push @tb_data, { ping_id => $ping->id,
                             ping_title => $ping->title,
                             ping_url => $ping->source_url,
                             ping_ip => $ping->ip,
                             ping_created => $df,
                             ping_odd => ($i++ % 2 ? 1 : 0) };
        }
    }
    my %param;
    $param{ping_loop} = \@tb_data;
    $param{saved_deleted} = $q->param('saved_deleted');
    $app->build_page('tb_cat_pings.tmpl', \%param);
}

sub reg_file {
    my $app = shift;
    my $q = $app->{query};
    my $uri = $app->base . $app->uri . '?__mode=reg_bm_js&bm_show=' .
              $q->param('bm_show') . '&bm_height=' . $q->param('bm_height');
    $app->{no_print_body} = 1;
    $app->set_header('Content-Disposition' => 'attachment; filename=mt.reg');
    $app->send_http_header('text/plain; name=mt.reg');
    $app->print(
        qq(REGEDIT4\r\n) .
        qq([HKEY_CURRENT_USER\\Software\\Microsoft\\Internet Explorer\\MenuExt\\MT It!]\r\n) .
        qq(@="$uri"\r\n) .
        qq("contexts"=hex:31));
    1;
}

sub reg_bm_js {
    my $app = shift;
    my $q = $app->{query};
    my $js = _bm_js($app->base . $app->uri, scalar $q->param('bm_show'),
                    scalar $q->param('bm_height'));
    $js =~ s!d=document!d=external.menuArguments.document!;
    $js =~ s!d\.location\.href!external.menuArguments.location.href!;
    $js =~ s!^javascript:!!;
    $app->{no_print_body} = 1;
    $app->send_http_header('text/plain');
    $app->print('<script language="javascript">' . $js . '</script>');
    1;
}

sub category_add { $_[0]->build_page('category_add.tmpl') }

sub category_do_add {
    my $app = shift;
    my $q = $app->{query};
    my $perms = $app->{perms}
        or return $app->error($app->translate("No permissions"));
    return $app->error($app->translate("Permission denied."))
        unless $perms->can_edit_categories;
    require MT::Category;
    my $name = $q->param('label') or return $app->error("No label");
    my $cat = MT::Category->new;
    $cat->blog_id(scalar $q->param('blog_id'));
    $cat->author_id($app->{user}->id);
    $cat->label($name);
    $cat->save or return $app->error($cat->errstr);
    my $id = $cat->id;
    $name = MT::Util::encode_js($name);
    my %param = (javascript => <<SCRIPT);
    o.doAddCategoryItem('$name', '$id');
SCRIPT
    $app->build_page('reload_opener.tmpl', \%param);
}

sub cc_return {
    my $app = shift;
    my $code = $app->{query}->param('license_code');
    my %param = (license_code => $code, license_name => MT::Util::cc_name($code));
    $app->build_page('cc_return.tmpl', \%param);
}

1;
