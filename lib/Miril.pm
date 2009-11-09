package Miril;

use warnings;
use strict;

=head1 NAME

Miril - A Static Content Management System

=head1 VERSION

Version 0.004

=cut

our $VERSION = '0.004';
$VERSION = eval $VERSION;

use base ("CGI::Application");

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
use Try::Tiny                                 qw(try catch);
use Module::Load                              qw(load);
use Miril::Error                              qw(miril_warn miril_die);
use Data::Page                                qw();
use XML::TreePP                               qw();
use POSIX                                     qw(strftime);

sub setup {
	my $self = shift;
	
	my $config_filename = $self->param('cfg_file');
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
	
	# global variable required by Miril::Error
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
	our $cfg_global = $cfg;

	
	# load model
	my $model_name = "Miril::Model::" . $self->cfg->model;
	try {
		load $model_name;
		$self->{model} = $model_name->new($self->cfg);
	} catch {
		miril_die("Could not load model", $_);
	};
	return unless $self->model;

	# load view
	my $view_name = "Miril::View::" . $self->cfg->view;
	try {
		load $view_name;
		$self->{view} = $view_name->new($self->cfg->tmpl_path);
	} catch {
		miril_die("Could not load view", $_);
	};

	# load filter
	my $filter_name = "Miril::Filter::" . $self->cfg->filter;
	try {
		load $filter_name;
		$self->{filter} = $filter_name->new($self->cfg);
	} catch {
		miril_die("Could not load filter", $_);
	};
	

	# load user manager
	my $user_manager_name = "Miril::UserManager::" . $self->cfg->user_manager;
	try {
		load $user_manager_name;
		$self->{user_manager} = $user_manager_name->new($self->cfg);
	} catch {
		miril_die("Could not load user manager", $_);
	};

	# configure authentication
	$self->authen->config( 
		DRIVER         => [ 'Generic', $self->user_manager->verification_callback ],
		LOGIN_RUNMODE  => 'login',
		LOGOUT_RUNMODE => 'logout',
		CREDENTIALS    => [ 'authen_username', 'authen_password' ],
		STORE          => [ 'Cookie', SECRET => $cfg->secret, EXPIRY => '+30d', NAME => 'miril_authen' ],
	);

	$self->authen->protected_runmodes(':all');	
}


### RUN MODES ###

sub error {
	my $self = shift;
	my $err_msg = shift;

	unless ($err_msg =~ /miril_processed_error/) {
		Miril::Error::process_error("Unspecified error", $err_msg) ;
	}

	my $tmpl = $self->load_tmpl('error');
	return $tmpl->output;
}

sub list_items {
	my $self = shift;
	my $q = $self->query;

	my @items = $self->model->get_items(
		author => ( $q->param('author') or undef ),
		title  => ( $q->param('title' ) or undef ),
		type   => ( $q->param('type'  ) or undef ),
		status => ( $q->param('status') or undef ),
		topic  => ( $q->param('topic' ) ? \($q->param('topic')) : undef ),
	);

	my @current_items = $self->paginate(@items);
	
	my $tmpl = $self->load_tmpl('list');
	$tmpl->param('items', \@current_items);
	return $tmpl->output;

}

sub search_items {
	my $self = shift;

	my $cfg = Miril->config;

	my $tmpl = $self->load_tmpl('search');

	$tmpl->param('statuses', $self->prepare_statuses );
	$tmpl->param('types',    $self->prepare_types    );
	$tmpl->param('topics',   $self->prepare_topics   ) if $cfg->topics;
	$tmpl->param('authors',  $self->prepare_authors  ) if $cfg->authors;

	return $tmpl->output;
}

sub create_item {
	my $self = shift;

	my $cfg = Miril->config;

	my $empty_item;

	$empty_item->{statuses} = $self->prepare_statuses;
	$empty_item->{types}    = $self->prepare_types;
	$empty_item->{authors}  = $self->prepare_authors if $cfg->authors;
	$empty_item->{topics}   = $self->prepare_topics  if $cfg->topics;

	my $tmpl = $self->load_tmpl('edit');
	$tmpl->param('item', $empty_item);
	
	return $tmpl->output;
}

sub edit_item {
	my $self = shift;

	my $cfg = Miril->config;

	my $id = $self->query->param('id');
	my $item = $self->model->get_item($id);
	
	my %cur_topics;

	#FIXME
	if (@{ $item->{topics} }) {
		%cur_topics = map {$_->id => 1} $item->topics;
	}
	
	$item->{authors}  = $self->prepare_authors($item->author) if $cfg->authors;
	$item->{topics}   = $self->prepare_topics(%cur_topics)    if $cfg->topics;
	$item->{statuses} = $self->prepare_statuses($item->status);
	$item->{types}    = $self->prepare_types($item->type);
	
	my $tmpl = $self->load_tmpl('edit');
	$tmpl->param('item', $item);

	$self->add_to_latest($item->id, $item->title);

	return $tmpl->output;
}

sub update_item {
	my $self = shift;
	my $q = $self->query;

	my $item = {
		'id'        => $q->param('id'),
		'author'    => $q->param('author'),
		'status'    => $q->param('status'),
		'text'      => $q->param('text'),
		'title'     => $q->param('title'),
		'type'      => $q->param('type'),
		'o_id'      => $q->param('o_id'),
	};

	$item->{topics} = [$self->query->param('topic')] if $q->param('topic');

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
		$item->{text} = $self->filter->to_xhtml($item->text);

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

	my $cfg = Miril->config;

	my $files_path = $cfg->files_path;
	my $files_http_dir = $cfg->files_http_dir;
	my @files;
	
	opendir(my $dir, $files_path) or miril_die("Cannot open files directory", $!);
	@files = grep { -f catfile($files_path, $_) } readdir($dir);
	closedir $dir;

	my @current_files = $self->paginate(@files);

	my @files_with_data = map +{ 
		name     => $_, 
		href     => "$files_http_dir/$_", 
		size     => format_bytes( -s catfile($files_path, $_) ), 
		modified => strftime( "%d/%m/%Y %H:%M", localtime( $self->get_last_modified_time(catfile($files_path, $_)) ) ), 
	}, @current_files;

	my $tmpl = $self->load_tmpl('files');
	$tmpl->param('files', \@files_with_data);
	return $tmpl->output;
}

sub upload_files {
	my $self = shift;

	my $cfg = Miril->config;
	
	my @filenames = $self->query->param('file');
	my @fhs = $self->query->upload('file');

	for ( my $i = 0; $i < @fhs; $i++) {

		my $filename = $filenames[$i];
		my $fh = $fhs[$i];

		if ($filename and $fh) {
			my $new_filename = catfile($cfg->files_path, $filename);
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

	my $cfg = Miril->config;

	my @filenames = $self->query->param('file');

	try {
		for (@filenames) {
			unlink( catfile($cfg->files_path, $_) )
				or miril_warn("Could not delete file", $!);
		}
	};

	return $self->redirect("?action=files");
}

sub publish {
	my $self = shift;

	my $cfg = Miril->config;
	
	my $do = $self->query->param("do");
	my $rebuild = $self->query->param("rebuild");

	if ($do) {
		my (@to_create, @to_update);

		my @items = $self->model->get_items;

		foreach my $item (@items) {
			my $src_modified = $item->modified_sec;

			my $target_filename = $self->get_target_filename($item->id, $item->type);
			
			if (-x $target_filename) {
				if ( $rebuild or ($src_modified > -M $target_filename) ) {
					push @to_update, $item->id;
				}
			} else {
				push @to_create, $item->id;
			}
		}

		for (@to_create, @to_update) {
			my $item = $self->model->get_item($_);
			
			$item->{text} = $self->filter->to_xhtml($item->text);
			$item->{teaser} = $self->filter->to_xhtml($item->teaser);

			my $type = first {$_->id eq $item->type} $cfg->types->type;
			warn $type->template;
			
			my $output = $self->view->load(
				name => $type->template, 
				params => {
					item => $item,
					cfg => $cfg,
			});

			my $new_filename = $self->get_target_filename($item->id, $item->type);

			my $fh = IO::File->new($new_filename, "w") 
				or miril_warn("Cannot open file $new_filename for writing", $!);
			if ($fh) {
				$fh->print( $output )
					or miril_warn("Cannot print to file $new_filename", $!);
				$fh->close;
			}
		}

		foreach my $list ($cfg->lists->list) {
			if ( 1 ) {

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

				my $output = $self->view->load(
					name => $list->template,
					params => {
						items => \@items,
						cfg => $cfg,
				});

				my $new_filename = catfile($cfg->output_path, $list->location);

				my $fh = IO::File->new($new_filename, "w") 
					or miril_warn("Cannot open file $new_filename for writing", $!);
				if ($fh) {
					$fh->print( $output )
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
sub view         { shift->{view};         }

### AUXILLIARY FUNCTIONS ###

sub get_target_filename {
	my $self = shift;

	my $cfg = Miril->config;

	my ($name, $type) = @_;

	my $current_type = first {$_->id eq $type} $cfg->types->type;
	my $target_filename = catfile($cfg->output_path, $current_type->location, $name . ".html");

	return $target_filename;
}

sub get_last_modified_time {
	my $self = shift;
	my $filename = shift;

	return time() - ( (-M $filename) * 60 * 60 * 24 );
}

sub get_latest {
	my $self = shift;
	
	my $cfg = Miril->config;

	require XML::TreePP;
	#FIXME
    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	my $tree;
	my @items;
	
	try { 
		$tree = $tpp->parsefile( $cfg->latest_data );
		# force array
		@items = dao @{ $tree->{xml}{item} };
	} catch {
		miril_warn($_);
	};
	

	return \@items;
}

sub add_to_latest {
	my $self = shift;

	my $cfg = Miril->config;

	my ($id, $title) = @_;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	my $tree;
	my @items;
	
	if ( -e $cfg->latest_data ) {
		try { 
			$tree = $tpp->parsefile( $cfg->latest_data );
			@items = @{ $tree->{xml}->{item} };
		} catch {
			miril_warn($_);
		};
	}

	@items = grep { $_->{id} ne $id } @items;
	unshift @items, { id => $id, title => $title};
	@items = @items[0 .. 9] if @items > 10;

	$tree->{xml}{item} = \@items;
	
	try { 
		$tpp->writefile( $cfg->latest_data, $tree );
	} catch {
		miril_warn($_);
	};
}

sub msg_add {
	my $self = shift;
	my $msg = shift;

	my @errors;
	#FIXME
	@errors = @{ $self->errors } if $self->errors;
	unshift @errors, $msg;
	$self->{errors} = \@errors;
}

sub generate_paged_url {
	my $self = shift;
	my $page_no = shift;

	my $q = $self->query;

	my $paged_url = '?action=' . $q->param('action');

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

sub paginate {
	my $self = shift;
	my @items = @_;
	
	my $cfg = Miril->config;

	return unless @items;

	if (@items > $cfg->items_per_page) {

		my $page = Data::Page->new;
		$page->total_entries(scalar @items);
		$page->entries_per_page($cfg->items_per_page);
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
		return $page->splice(\@items);

	} else {
		return @items;
	}
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

	if ($self->pager) {

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

sub config {
	return $Miril::cfg_global;
}

sub prepare_authors {
	my ($self, $selected) = @_;
	my $cfg = Miril->config;
	my @authors;
	if ($selected) {
		@authors = map +{ name => $_, id => $_ , selected => $_ eq $selected }, $cfg->authors;
	} else {
		@authors = map +{ name => $_, id => $_  }, $cfg->authors;
	}
	return \@authors;
}

sub prepare_statuses {
	my ($self, $selected) = @_;
	my $cfg = Miril->config;
	my @statuses = map +{ name => $_, id => $_, selected => $_ eq $selected }, $cfg->statuses;
	return \@statuses;
}

sub prepare_topics {
	my ($self, %selected) = @_;
	my $cfg = Miril->config;
	my @topics   = map +{ name => $_->name, id => $_->id, selected => $selected{$_->id} }, $cfg->topics;
	return \@topics;
}

sub prepare_types {
	my ($self, $selected) = @_;
	my $cfg = Miril->config;
	my @types = map +{ name => $_->name, id => $_->id, selected => $_->id eq $selected }, $cfg->types;
	return \@types;
}

1;


=head1 DESCRPTION

Miril is a lightweight static content management system written in perl and based on CGI::Application. It is designed to be easy to deploy and easy to use. Documentation is currently lacking, read L<Miril::Manual> to get started. 

=head1 AUTHOR

Peter Shangov, C<< <pshangov at yahoo.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter Shangov.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

