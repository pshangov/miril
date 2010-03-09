package CGI::Application::Miril;

use strict;
use warnings;

use autodie;
use Try::Tiny;
use Exception::Class;

use base 'CGI::Application';

use CGI::Application::Plugin::Authentication;
use CGI::Application::Plugin::Redirect;
use CGI::Application::Plugin::Forward;
use Module::Load;
use File::Spec::Functions qw(catfile);

use Miril;
use Miril::Exception;
use Miril::Theme::Flashyweb;
use Miril::View;
use Miril::InputValidator;

### ACCESSORS ###

use Object::Tiny qw(
	view
	user_manager
	miril
	validator
);

### SETUP ###

sub setup {
	my $self = shift;

	#use Data::Dumper;
	#warn Data::Dumper::Dumper(\%ENV);
	
	# setup runmodes

    $self->mode_param('action');
    $self->run_modes(
    	'list'         => 'posts_list',
        'edit'         => 'posts_edit',
        'create'       => 'posts_create',
        'delete'       => 'posts_delete',
        'view'         => 'posts_view',
        'update'       => 'posts_update',
		'publish'      => 'posts_publish',
		'files'        => 'files_list',
		'upload'       => 'files_upload',
		'unlink'       => 'files_delete',
		'search'       => 'search',
		'login'        => 'login',
		'logout'       => 'logout',
		'account'      => 'account',
	);

	$self->start_mode('list');
	$self->error_mode('error');

	# setup miril
	my $config_filename = $self->param('cfg_file');
	$config_filename = 'miril.config' unless $config_filename;
	$self->{miril}= Miril->new($config_filename);
	
	# configure authentication
	try {
		my $user_manager_name = "Miril::UserManager::" . $self->miril->cfg->user_manager;
		load $user_manager_name;
		$self->{user_manager} = $user_manager_name->new($self->miril);
	} catch {
		Miril::Exception->throw(
			errorvar => $_,
			message  => 'Could not load user manager',
		);
	};

	$self->authen->config( 
		DRIVER         => [ 'Generic', $self->user_manager->verification_callback ],
		LOGIN_RUNMODE  => 'login',
		LOGOUT_RUNMODE => 'logout',
		CREDENTIALS    => [ 'authen_username', 'authen_password' ],
		STORE          => [ 'Cookie', SECRET => $self->miril->cfg->secret, EXPIRY => '+30d', NAME => 'miril_authen' ],
	);

	$self->authen->protected_runmodes(':all');

	# load view
	$self->{view} = Miril::View->new(
		theme            => Miril::Theme::Flashyweb->new,
		is_authenticated => $self->authen->is_authenticated,
		latest           => $self->miril->store->get_latest,
	);

	$self->{validator} = Miril::InputValidator->new;
}

### RUN MODES ###

sub error {
	my ($self, $e) = @_;
	ref $e ? die $e->errorvar : die $e;

	my $tmpl = $self->miril->view->load('error');
	$tmpl->param('error', $e);
	return $tmpl->output;
}

sub posts_list {
	my $self = shift;
	my $q = $self->query;

	my @items = $self->miril->store->get_posts(
		author => ( $q->param('author') or undef ),
		title  => ( $q->param('title' ) or undef ),
		type   => ( $q->param('type'  ) or undef ),
		status => ( $q->param('status') or undef ),
		topic  => ( $q->param('topic' ) ? \($q->param('topic')) : undef ),
	);

	my @current_items = $self->_paginate(@items);
	
	my $tmpl = $self->view->load('list');
	$tmpl->param('items', \@current_items);
	return $tmpl->output;

}

sub search {
	my $self = shift;

	my $cfg = $self->miril->cfg;

	my $tmpl = $self->view->load('search');

	$tmpl->param('statuses', $self->_prepare_statuses );
	$tmpl->param('types',    $self->_prepare_types    );
	$tmpl->param('topics',   $self->_prepare_topics   ) if $cfg->topics;
	$tmpl->param('authors',  $self->_prepare_authors  ) if $cfg->authors;

	return $tmpl->output;
}

sub posts_create {
	my $self = shift;

	my $cfg = $self->miril->cfg;

	my $empty_item;

	$empty_item->{statuses} = $self->_prepare_statuses;
	$empty_item->{types}    = $self->_prepare_types;
	$empty_item->{authors}  = $self->_prepare_authors if $cfg->authors;
	$empty_item->{topics}   = $self->_prepare_topics  if $cfg->topics;

	my $tmpl = $self->view->load('edit');
	$tmpl->param('item', $empty_item);
	
	return $tmpl->output;
}

sub posts_edit {
	my $self = shift;

	my $cfg = $self->miril->cfg;

	my $id = $self->query->param('id');
	# check if $item is defined
	my $item = $self->miril->store->get_post($id);
	
	my %cur_topics;

	#FIXME
	if (@{ $item->{topics} }) {
		%cur_topics = map {$_->id => 1} $item->topics;
	}
	
	$item->{authors}  = $self->_prepare_authors($item->author) if $cfg->authors;
	$item->{topics}   = $self->_prepare_topics(%cur_topics)    if $cfg->topics;
	$item->{statuses} = $self->_prepare_statuses($item->status);
	$item->{types}    = $self->_prepare_types($item->type);
	
	my $tmpl = $self->view->load('edit');
	$tmpl->param('item', $item);

	$self->miril->store->add_to_latest($item->id, $item->title);

	return $tmpl->output;
}

sub posts_update {
	my $self = shift;
	my $q = $self->query;

	my $item = {
		'id'     => $q->param('id'),
		'author' => ( $q->param('author') or undef ),
		'status' => ( $q->param('status') or undef ),
		'text'   => ( $q->param('text')   or undef ),
		'title'  => ( $q->param('title')  or undef ),
		'type'   => ( $q->param('type')   or undef ),
		'old_id' => ( $q->param('old_id') or undef ),
	};

	# SHOULD NOT BE HERE
	$item->{topics} = [$q->param('topic')] if $q->param('topic');

	$self->miril->store->save($item);

	return $self->redirect("?action=view&id=" . $item->{id});
}

sub posts_delete {
	my $self = shift;

	my $id = $self->query->param('old_id');
	$self->miril->store->delete($id);

	return $self->redirect("?action=list");
}

sub posts_view {
	my $self = shift;
	
	my $q = $self->query;
	my $id = $q->param('old_id') ? $q->param('old_id') : $q->param('id');

	my $item = $self->miril->store->get_post($id);
	if ($item) {
		$item->{text} = $self->miril->filter->to_xhtml($item->text);

		my $tmpl = $self->view->load('view');
		$tmpl->param('item', $item);
		return $tmpl->output;
	} else {
		return $self->redirect("?action=list");	
	}
}

sub login {
	my $self = shift;
	
	my $tmpl = $self->view->load('login');
	return $tmpl->output;
}

sub logout {
	my $self = shift;

	$self->authen->logout();
	
	return $self->redirect("?action=login");
}

sub account {
	my $self = shift;
	my $q = $self->query;

	if (   $q->param('name')
		or $q->param('email')
		or $q->param('new_password') 
	) {
	
		my $username        = $q->param('username');
		my $name            = $q->param('name');
		my $email           = $q->param('email');
		my $new_password    = $q->param('new_password');
		my $retype_password = $q->param('retype_password');
		my $password        = $q->param('password');

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

	} else {
	
		my $username = $self->authen->username;
		my $user = $self->user_manager->get_user($username);

		my $tmpl = $self->view->load('account');
		$tmpl->param('user', $user);
		return $tmpl->output;
	} 
}

sub files_list {
	my $self = shift;

	my $cfg = $self->miril->cfg;

	my $files_path = $cfg->files_path;
	my $files_http_dir = $cfg->files_http_dir;
	my @files;
	
	try {
		opendir(my $dir, $files_path);
		@files = grep { -f catfile($files_path, $_) } readdir($dir);
		closedir $dir;
	} catch {
		Miril::Exception->throw(
			errorvar => $_,
			message  => 'Could not read files directory',
		);
	};

	my @current_files = $self->_paginate(@files);

	my @files_with_data = map +{ 
		name     => $_, 
		href     => "$files_http_dir/$_", 
		size     => format_bytes( -s catfile($files_path, $_) ), 
		modified => strftime( "%d/%m/%Y %H:%M", localtime( $self->_get_last_modified_time(catfile($files_path, $_)) ) ), 
	}, @current_files;

	my $tmpl = $self->view->load('files');
	$tmpl->param('files', \@files_with_data);
	return $tmpl->output;
}

sub files_upload {
	my $self = shift;
	my $q = $self->query;
	my $cfg = $self->miril->cfg;

	if ( $q->param('file') or $q->upload('file') ) {
	
		my @filenames = $q->param('file');
		my @fhs = $q->upload('file');

		for ( my $i = 0; $i < @fhs; $i++) {

			my $filename = $filenames[$i];
			my $fh = $fhs[$i];

			if ($filename and $fh) {
				my $new_filename = catfile($cfg->files_path, $filename);
				try {
					my $new_fh = IO::File->new($new_filename, "w");
					copy($fh, $new_fh);
					$new_fh->close;
				} catch {
					Miril::Exception->throw(
						errorvar => $_,
						message  => 'Could not upload file',
					);
				}
			}
		}

		return $self->redirect("?action=files");

	} else {
		my $tmpl = $self->view->load('upload');
		return $tmpl->output;
	}
}

sub files_delete {
	my $self = shift;	
	my $cfg = $self->miril->cfg;
	my $q = $self->query;

	my @filenames = $q->param('file');

	try {
		for (@filenames) {
			try { 
				unlink( catfile($cfg->files_path, $_) ) 
			} catch {
				Miril::Exception->throw(
					errorvar => $_,
					message  => 'Could not delete file',
				);
			};
		}
	};

	return $self->redirect("?action=files");
}

sub posts_publish {
	my $self = shift;

	my $cfg = $self->miril->cfg;
	
	my $do = $self->query->param("do");
	my $rebuild = $self->query->param("rebuild");

	if ($do) {
		$self->publish($rebuild);
		return $self->redirect("?action=list");
	} else {
		my $tmpl = $self->view->load('publish');
		return $tmpl->output;
	}
}

### PRIVATE METHODS ###

sub _prepare_authors {
	my ($self, $selected) = @_;
	my $cfg = $self->miril->cfg;
	my @authors;
	if ($selected) {
		@authors = map +{ name => $_, id => $_ , selected => $_ eq $selected }, $cfg->authors;
	} else {
		@authors = map +{ name => $_, id => $_  }, $cfg->authors;
	}
	return \@authors;
}

sub _prepare_statuses {
	my ($self, $selected) = @_;
	my $cfg = $self->miril->cfg;
	my @statuses = map +{ name => $_, id => $_, selected => $_ eq $selected }, $cfg->statuses;
	return \@statuses;
}

sub _prepare_topics {
	my ($self, %selected) = @_;
	my $cfg = $self->miril->cfg;
	my @topics   = map +{ name => $_->name, id => $_->id, selected => $selected{$_->id} }, $cfg->topics;
	return \@topics;
}

sub _prepare_types {
	my ($self, $selected) = @_;
	my $cfg = $self->miril->cfg;
	my @types = map +{ name => $_->name, id => $_->id, selected => $_->id eq $selected }, $cfg->types;
	return \@types;
}

sub _paginate {
	my $self = shift;
	my @items = @_;
	
	my $cfg = $self->miril->cfg;

	return unless @items;

	if (@items > $cfg->items_per_page) {

		my $page = Data::Page->new;
		$page->total_entries(scalar @items);
		$page->entries_per_page($cfg->items_per_page);
		$page->current_page($self->query->param('page_no') ? $self->query->param('page_no') : 1);
		
		my $pager;
		
		if ($page->current_page > 1) {
			$pager->{first}    = $self->_generate_paged_url($page->first_page);
			$pager->{previous} = $self->_generate_paged_url($page->previous_page);
		}

		if ($page->current_page < $page->last_page) {
			$pager->{'last'} = $self->_generate_paged_url($page->last_page);
			$pager->{'next'} = $self->_generate_paged_url($page->next_page);
		}

		$self->view->{pager} = $pager;
		return $page->splice(\@items);

	} else {
		return @items;
	}
}

sub _generate_paged_url {
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

sub _get_last_modified_time {
	my $self = shift;
	my $filename = shift;

	return time() - ( (-M $filename) * 60 * 60 * 24 );
}

1;
