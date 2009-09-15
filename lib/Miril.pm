package Miril;

use warnings;
use strict;

=head1 NAME

Miril - A Static Content Management System

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use base ("CGI::Application");

use lib 'c:\Documents\Development\CGI-Cookie-Storable\lib';

use CGI::Application::Plugin::Redirect        qw(redirect);
use CGI::Application::Plugin::Forward         qw(forward);
use CGI::Application::Plugin::Authentication  qw(authen);
use HTML::Template::Pluggable                 qw();
use HTML::Template::Plugin::Dot;              # what does it export?
use IO::File                                  qw();
use Cwd                                       qw(cwd);
use File::Copy                                qw(copy);
use List::Util                                qw(first);
use Scalar::Util                              qw(reftype);
use Time::Format                              qw(time_format);
use Number::Format                            qw(format_bytes);
use File::Spec::Functions                     qw(catfile);
use Data::AsObject                            qw(dao);
use Data::Dumper                              qw(Dumper);
use CGI::Cookie;
use Try::Tiny                                 qw(try catch);
use Module::Load                              qw(load);
use Miril::Error                              qw(miril_warn miril_die);
use Data::Page                                qw();

sub setup {
	my $self = shift;
	my $config_filename = shift;
	$config_filename = 'miril.config' unless $config_filename;

    $self->mode_param('action');
    $self->run_modes(
    	'list'         => 'list_items',
        'edit'         => 'edit_item',
        'create'       => 'create_item',
        'delete'       => 'delete_item',
        'view'         => 'view_item',
        'update'       => 'update_item',
		'login'        => 'login',
		'logout'       => 'logout',
		'account'      => 'account',
		'update_user'  => 'update_user',
		'files'        => 'view_files',
		'upload_files' => 'upload_files',
		'upload'       => 'upload',
		'delete_files' => 'delete_files',
		'publish'      => 'publish',
		'quick_open'   => 'quick_open',
		'search'       => 'search_items',
	);

	$self->start_mode('list');
	$self->error_mode('error');
	
	$Miril::Error::app = $self;
	# load templates
	require Miril::Theme::Flashyweb;
	$self->{tmpl} = Miril::Theme::Flashyweb->new;
	
	# load configuration
	require Miril::Config;

	my $cfg;
	try {
		$cfg = Miril::Config->new($config_filename);
	} catch {
		miril_die("Could not open configuration file", $_);
	};
	return unless $cfg;

	$self->{cfg} = $cfg;

	
	
	# load model
	my $model_name = "Miril::Model::" . $self->cfg->model;
	try {
		load $model_name;
		$self->{model} = $model_name->new($self->cfg);
	} catch {
		miril_die("Could not load model", $_);
	};
	return unless $self->model;

	# load filter
	my $filter_name = "Miril::Filter::" . $self->cfg->filter;
	try {
		load $filter_name;
	} catch {
		miril_die("Could not load filter", $_);
	};
	my $filter = $filter_name->new($self->cfg);
	$self->{filter} = $filter;

	# configure user management
	my $user_manager_name = "Miril::UserManager::" . $self->cfg->user_manager;
	try {
		load $user_manager_name;
	} catch {
		miril_die("Could not load user manager", $_);
	};
	my $user_manager = $user_manager_name->new($self->cfg);
	$self->{user_manager} = $user_manager;

	# configure authentication
	$self->authen->config( 
		DRIVER         => [ 'Generic', $self->user_manager->verification_callback ],
		LOGIN_RUNMODE  => 'login',
		LOGOUT_RUNMODE => 'logout',
		CREDENTIALS    => [ 'authen_username', 'authen_password' ],
		STORE          => [ 'Cookie', SECRET => $cfg->secret, EXPIRY => '+30d', NAME => 'miril_authen' ],
	);

	$self->authen->protected_runmodes(':all');	
	
	#my %cookies = CGI::Cookie->fetch;
	#my $msg_cookie = $cookies{'miril_msg'};

	#$self->{msg_cookie} = $msg_cookie;

	#if ($msg_cookie) {
	#	my @messages = map +{ msg => $_ }, $msg_cookie->value;
	#	$self->{msg} = \@messages
	#}

	#miril_warn('test error');
	#$self->msg_add("kaboom");
	#$self->msg_add("basta");
}

=pod
sub cgiapp_postrun {
	my $self = shift;
	my $cookie;

	$self->msg_cookie 
		? $cookie = $self->msg_cookie 
		: $cookie = CGI::Cookie->new(
			-name => 'miril_msg',
			-expires => '+1d',
		); 
	my $errors = $self->errors;
	if ($errors) {
		$cookie->value($errors);
	} else {
		$cookie->expires('-1d');
	}

	$self->header_add(-cookie=>[$cookie]);
}
=cut

### RUN MODES ###

sub error {
	my $self = shift;
	my $err_msg = shift;

	my $tmpl = $self->load_tmpl('error');
	return $tmpl->output;
}

sub list_items {
	my $self = shift;

	my @items = $self->model->get_items(
		author            => ( $self->query->param('author') or undef ),
		title             => ( $self->query->param('title')  or undef ),
		type              => ( $self->query->param('type')   or undef ),
		status            => ( $self->query->param('status') or undef ),
		topic             => ( $self->query->param('topic')  or undef ),
		#created_before    => $self->query->param('created_before'),
		#created_on        => $self->query->param('created_on'),
		#created_after     => $self->query->param('created_after'),
		#updated_before    => $self->query->param('updated_before'),
		#updated_on        => $self->query->param('updated_on'),
		#updated_after     => $self->query->param('updated_after'),
		#published_before  => $self->query->param('published_before'),
		#published_on      => $self->query->param('published_on'),
		#published_after   => $self->query->param('published_after'),
	);

	my @current_items;
	
	if (@items) {

		if (@items > $self->cfg->items_per_page) {

			my $page = Data::Page->new;
			$page->total_entries(scalar @items);
			$page->entries_per_page($self->cfg->items_per_page);
			$page->current_page($self->query->param('page_no') ? $self->query->param('page_no') : 1);
			
			my $pager;
			
			if ($page->current_page > 1) {
				$pager->{first}    = $self->generate_paged_url($page->first_page);
				$pager->{previous} = $self->generate_paged_url($page->previous_page);
			}

			warn $page->first_page;

			if ($page->current_page < $page->last_page) {
				$pager->{'last'} = $self->generate_paged_url($page->last_page);
				$pager->{'next'} = $self->generate_paged_url($page->next_page);
			}

			$self->{pager} = $pager;
			@current_items = $page->splice(\@items);

		} else {
			@current_items = @items;
		}
		 
	}

	my $tmpl = $self->load_tmpl('list');
	$tmpl->param('items', \@current_items);
	return $tmpl->output;

}

sub search_items {
	my $self = shift;
	my $tmpl = $self->load_tmpl('search');

	my @authors  = map +{ "cfg_author", $_ }, $self->cfg->authors->author;
	my @statuses = map +{ "cfg_status", $_ }, $self->cfg->workflow->status;
	my @types    = map +{ "cfg_type",  $_->name, "cfg_m_type",   $_->m_name }, $self->cfg->types->type;
	my @topics   = map +{ "cfg_topic", $_->name, "cfg_topic_id", $_->id },     $self->cfg->topics->topic;

	unshift @authors,  { cfg_author => undef };
	unshift @statuses, { cfg_status => undef };
	unshift @types,    { cfg_type => undef, cfg_m_type => undef };
	unshift @topics,   { cfg_topic => undef, cfg_topic_id => undef };

	$tmpl->param('authors',  \@authors);
	$tmpl->param('statuses', \@statuses);
	$tmpl->param('types',    \@types);
	$tmpl->param('topics',   \@topics);

	return $tmpl->output;
}

sub create_item {
	my $self = shift;
	my $tmpl = $self->load_tmpl('edit');

	my $empty_item = {};

	my @authors  = map +{ "cfg_author", $_ }, $self->cfg->authors->author;
	my @statuses = map +{ "cfg_status", $_ }, $self->cfg->workflow->status;
	my @types    = map +{ "cfg_type",  $_->name, "cfg_m_type",   $_->m_name }, $self->cfg->types->type;
	my @topics   = map +{ "cfg_topic", $_->name, "cfg_topic_id", $_->id },     $self->cfg->topics->topic;
	
	$empty_item->{authors}  = \@authors;
	$empty_item->{statuses} = \@statuses;
	$empty_item->{types}    = \@types;
	$empty_item->{topics}   = \@topics;
	
	$tmpl->param('item', [$empty_item]);
	
	return $tmpl->output;
}

sub edit_item {
	my $self = shift;

	my $id = $self->query->param('id');
	my $item = $self->model->get_item($id);
	
	my $cur_author = $item->{author};
	my $cur_status = $item->{status};
	my $cur_topic  = $item->{topic}->{id};
	my $cur_type   = $item->{type};
	
	# the "+" instructs map to produce a list of hashrefs, see "perldoc -f map"
	my @authors  = map +{ "cfg_author", $_, "selected", $_ eq $cur_author ? 1 : 0 }, $self->cfg->authors->author;
	my @statuses = map +{ "cfg_status", $_, "selected", $_ eq $cur_status ? 1 : 0 }, $self->cfg->workflow->status;
	my @types    = map +{ "cfg_type",  $_->name, "cfg_m_type",   $_->m_name, "selected", $_->m_name eq $cur_type   ? 1 : 0 }, $self->cfg->types->type;
	my @topics   = map +{ "cfg_topic", $_->name, "cfg_topic_id", $_->id,     "selected", $_->id     eq $cur_topic  ? 1 : 0 }, $self->cfg->topics->topic;
	
	$item->{authors}  = \@authors;
	$item->{statuses} = \@statuses;
	$item->{topics}   = \@topics;
	$item->{types}    = \@types;

	my $tmpl = $self->load_tmpl('edit');
	$tmpl->param('item', [$item]);

	$self->add_to_latest($item->{id}, $item->{title});

	return $tmpl->output;
}

sub update_item {
	my $self = shift;
	my $item = {
		'id'        => $self->query->param('id'),
		'author'    => $self->query->param('author'),
		'status'    => $self->query->param('status'),
		'text'      => $self->query->param('text'),
		'title'     => $self->query->param('title'),
		'topic'     => $self->query->param('topic'),
		'type'      => $self->query->param('type'),
		'o_id'      => $self->query->param('o_id'),
	};

	$self->model->save($item);

	return $self->redirect("?action=view&id=" . $item->{id});
}

sub delete_item {
	my $self = shift;

	my $id = $self->query->param('o_id');
	$self->model->delete($id);

	return $self->redirect("?action=list");
}

sub view_item {
	my $self = shift;
	
	 
	my $id = $self->query->param('o_id') ? $self->query->param('o_id') : $self->query->param('id');

	my $item = $self->model->get_item($id);
	if ($item) {
		$item->{text} = $self->filter->to_xhtml($item->{text});

		my $tmpl = $self->load_tmpl('view');
		$tmpl->param('item', $item);
		return $tmpl->output;
	} else {
		return $self->redirect("?action=list");	
	}
}

sub login {
	my $self = shift;
	
	my $tmpl = $self->load_tmpl('login');
	return $tmpl->output;
}

sub logout {
	my $self = shift;

	$self->authen->logout();
	
	return $self->redirect("?action=login");
}

sub account {
	my $self = shift;

	my $username = $self->authen->username;
	my $user = $self->user_manager->get_user($username);

	my $tmpl = $self->load_tmpl('account');
	$tmpl->param('user', [$user]);
	return $tmpl->output;
}

sub update_user {
	my $self = shift;
	
	my $username        = $self->query->param('username');
	my $name            = $self->query->param('name');
	my $email           = $self->query->param('email');
	my $new_password    = $self->query->param('new_password');
	my $retype_password = $self->query->param('new_password_2');
	my $password        = $self->query->param('password');

	my $user = $self->user_manager->get_user($username);
	my $encrypted = $self->user_manager->encrypt($password);

	if ( $name and $email and ($encrypted eq $user->{password}) ) {
		$user->{name} = $name;
		$user->{email} = $email;
		if ( $new_password and ($new_password eq $retype_password) ) {
			$user->{password} = $self->user_manager->encrypt($new_password);
		}
		$self->user_manager->set_user($user);

		return $self->redirect("?"); 
	}

	return $self->redirect("?action=account");
}

sub view_files {
	my $self = shift;

	my $files_dir = $self->cfg->files_dir;
	my $files_http_dir = $self->cfg->files_http_dir;
	my @files;
	
	opendir(my $dir, $files_dir) or miril_die($!);
	@files = grep { -f catfile($files_dir, $_) } readdir($dir);
	closedir $dir;

	my @files_with_data = map +{ 
		name     => $_, 
		href     => "$files_http_dir/$_", 
		size     => format_bytes( -s catfile($files_dir, $_) ), 
		modified => time_format( 'yyyy/mm/dd hh:mm', $self->get_last_modified_time( catfile($files_dir, $_) ) ), 
	}, @files;

	my $tmpl = $self->load_tmpl('files');
	$tmpl->param('files', [@files_with_data]);
	return $tmpl->output;
}

sub upload_files {
	my $self = shift;
	
	my @filenames = $self->query->param('file');
	my @fhs = $self->query->upload('file');

	for ( my $i = 0; $i < @fhs; $i++) {

		my $filename = $filenames[$i];
		my $fh = $fhs[$i];

		if ($filename and $fh) {
			my $new_filename = catfile($self->cfg->files_dir, $filename);
			my $new_fh = IO::File->new($new_filename, "w") 
				or miril_warn("Could not upload file", $!);
			copy($fh, $new_fh) 
				or miril_warn("Could not upload file", $!);
			$new_fh->close;
		}
	}

	return $self->redirect("?action=files");
}

sub upload {
	my $self = shift;
	
	my $tmpl = $self->load_tmpl('upload');
	return $tmpl->output;
}

sub delete_files {
	my $self = shift;
	
	my @filenames = $self->query->param('file');

	try {
		for (@filenames) {
			unlink( catfile($self->cfg->files_dir, $_) )
				or miril_warn("Couod not delete file", $!);
		}
	};

	return $self->redirect("?action=files");
}

sub publish {
	my $self = shift;
	
	my $do = $self->query->param("do");
	my $rebuild = $self->query->param("rebuild");

	if ($do) {
		my (@to_create, @to_update);

		my @items = $self->model->get_items;

		foreach my $item (@items) {
			my $src_modified = $item->{modified_sec};

			my $target_filename = $self->get_target_filename($item->{id}, $item->{type});
			
			if (-x $target_filename) {
				if ( $rebuild or ($src_modified > -M $target_filename) ) {
					push @to_update, $item->{id};
				}
			} else {
				push @to_create, $item->{id};
			}
		}

		for (@to_create, @to_update) {
			my $item = $self->model->get_item($_);
			
			$item->{text} = $self->filter->to_xhtml($item->{text});
			$item->{teaser} = $self->filter->to_xhtml($item->{teaser});

			my $type = first {$_->m_name eq $item->{type}} $self->cfg->types->type;
			
			my $tmpl = $self->load_user_tmpl($type->template);
			$tmpl->param('item', $item);
			$tmpl->param('cfg', $self->cfg);

			my $new_filename = $self->get_target_filename($item->{id}, $item->{type});

			my $fh = IO::File->new($new_filename, "w") 
				or miril_warn("Cannot open file $new_filename for writing", $!);
			if ($fh) {
				$fh->print( $tmpl->output )
					or miril_warn("Cannot print to file $new_filename", $!);
				$fh->close;
			}
		}

		foreach my $list ($self->cfg->lists->list) {
			if ( $list->id eq "front_page" or $list->id eq "archive" or $list->id eq "feed" ) {

				my @params = qw(
					author
					type
					status
					topic
					created_before
					created_on
					created_after
					updated_before
					updated_on
					updated_after
					published_before
					published_on
					published_after
					last
				);

				my %params;

				foreach my $param (@params) {
					if ( exists $list->match->{$param} ) {
						$params{$param} = $list->match->{$param};
					}
				}

				my @items = $self->model->get_items( %params );

				my $tmpl = $self->load_user_tmpl($list->template);
				$tmpl->param('items', \@items);
				$tmpl->param('cfg', $self->cfg);

				my $new_filename = catfile($self->cfg->root_dir, $list->location);

				my $fh = IO::File->new($new_filename, "w") 
					or miril_warn("Cannot open file $new_filename for writing", $!);
				if ($fh) {
					$fh->print( $tmpl->output )
						or miril_warn("Cannot print to file $new_filename", $!);
					$fh->close;
				}

			}
		}
		return $self->redirect("?action=list");
		
	} else {
		my $tmpl = $self->load_tmpl('publish');
		return $tmpl->output;
	}
}

sub msg {
	my $self = shift;
	$self->{msg} ? return $self->{msg} : return [];
}

### ACCESSORS ###

sub model        { shift->{model};        }
sub filter       { shift->{filter};       }
sub cfg          { shift->{cfg};          }
sub tmpl         { shift->{tmpl};         }
sub errors       { shift->{errors};       }
sub user_manager { shift->{user_manager}; }
sub msg_cookie   { shift->{msg_cookie};   }
sub pager        { shift->{pager};        }

### AUXILLIARY FUNCTIONS ###

sub get_target_filename {
	my $self = shift;
	my ($name, $type) = @_;

	my $current_type = first {$_->m_name eq $type} $self->cfg->types->type;
	my $target_filename = catfile($self->cfg->root_dir, $current_type->location, $name . ".html");

	return $target_filename;
}

sub get_last_modified_time {
	my $self = shift;
	my $filename = shift;

	return time() - ( (-M $filename) * 60 * 60 * 24 );
}

sub get_latest {
	my $self = shift;
	
	require XML::TreePP;
    my $tpp = XML::TreePP->new();
	my $tree;
	
	try { 
		$tree = $tpp->parsefile( $self->cfg->latest_data );
	} catch {
		miril_warn($_);
	};
	my @items = dao @{ $tree->{xml}->{item} };

	return \@items;
}

sub add_to_latest {
	my $self = shift;
	my ($id, $title) = @_;

	require XML::TreePP;
    my $tpp = XML::TreePP->new();
	my $tree;
	
	try { 
		$tree = $tpp->parsefile( $self->cfg->latest_data );
	} catch {
		miril_warn($_);
	};

	my @items = @{ $tree->{xml}->{item} };
	@items = grep { $_->{id} ne $id } @items;
	unshift @items, { id => $id, title => $title};
	@items = @items[0 .. 9] if @items > 10;

	$tree->{xml}->{item} = \@items;
	
	try { 
		$tpp->writefile( $self->cfg->latest_data, $tree );
	} catch {
		miril_warn($_);
	};
}

sub msg_add {
	my $self = shift;
	my $msg = shift;

	my @errors;
	@errors = @{ $self->errors } if $self->errors;
	unshift @errors, $msg;
	$self->{errors} = \@errors;
}

sub generate_paged_url {
	my $self = shift;
	my $page_no = shift;

	my $q = $self->query;

	my $paged_url = '?action=list';

	if (
		$q->param('title')  or
		$q->param('author') or
		$q->param('type')   or
		$q->param('status') or
		$q->param('topic')
	) {
		$paged_url .=   '&title='  . $q->param('title')
		              . '&author=' . $q->param('author') 
		              . '&type='   . $q->param('type') 
		              . '&status=' . $q->param('status')
		              . '&topic='  . $q->param('topic');
	}

	$paged_url .= "&page_no=$page_no";

	return $paged_url;
}

sub load_tmpl {
	my $self = shift;
	my $name = shift;
	my %options = @_;

	my $text = $self->tmpl->get($name);
	
	# get css
	my $css_text = $self->tmpl->get('css');
	my $css = HTML::Template::Pluggable->new( scalarref => \$css_text, die_on_bad_params => 0 );

	# get header
	my $header_text = $self->tmpl->get('header');
	my $header = HTML::Template::Pluggable->new( scalarref => \$header_text, die_on_bad_params => 0 );
	$header->param('authenticated', $self->authen->is_authenticated ? 1 : 0);
	$header->param('css', $css->output);
	my @error_stack = Miril::Error::error_stack();
	$header->param('has_error', 1 ) if @error_stack;
	$header->param('error', [@error_stack] );

	# get sidebar
	my $sidebar_text = $self->tmpl->get('sidebar');
	my $sidebar = HTML::Template::Pluggable->new( scalarref => \$sidebar_text, die_on_bad_params => 0 );
	$sidebar->param('latest', $self->get_latest);

	# get footer
	my $footer_text = $self->tmpl->get('footer');
	my $footer = HTML::Template::Pluggable->new( scalarref => \$footer_text, die_on_bad_params => 0 );
	$footer->param('authenticated', $self->authen->is_authenticated ? 1 : 0);
	$footer->param('sidebar', $sidebar->output);
	
	my $tmpl = HTML::Template::Pluggable->new( scalarref => \$text, die_on_bad_params => 0 );
	$tmpl->param('authenticated', $self->authen->is_authenticated ? 1 : 0);
	$tmpl->param('header' => $header->output, 'footer' => $footer->output );

	if ( ($name eq 'list') and $self->pager ) {

		my $pager_text = $self->tmpl->get('pager');
		my $pager = HTML::Template::Pluggable->new( scalarref => \$pager_text, die_on_bad_params => 0 );
		$pager->param('first', $self->pager->{first});
		$pager->param('last', $self->pager->{last});
		$pager->param('previous', $self->pager->{previous});
		$pager->param('next', $self->pager->{next});

		warn $pager->output;
		
		$tmpl->param('pager' => $pager->output );
	}

	

	return $tmpl;
}

sub load_user_tmpl {
	my $self = shift;
	my $tmpl_file = shift;
	my $tmpl;
	
	try {
		$tmpl = HTML::Template::Pluggable->new( 
			filename          => catfile( $self->cfg->user_tmpl_dir, $tmpl_file ), 
			path              => $self->cfg->user_tmpl_dir,
			die_on_bad_params => 0,
			global_vars       => 1,
		);
	} catch {
		miril_die($_);
	};
	
	return $tmpl;
}

1;


=head1 DESCRPTION

Miril is a lightweight static content management system written in perl and based on CGI::Application. It is designed to be easy to deploy and easy to use. Documentation is currently lacking, read L<Miril::Manual> to get started. 

=head1 AUTHOR

Peter Shangov, C<< <pshangov at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-miril at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Miril>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Miril


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Miril>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Miril>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Miril>

=item * Search CPAN

L<http://search.cpan.org/dist/Miril/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter Shangov.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Miril
