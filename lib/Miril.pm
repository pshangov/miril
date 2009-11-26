package Miril;

use warnings;
use strict;

=head1 NAME

Miril - A Static Content Management System

=head1 VERSION

Version 0.006

=cut

our $VERSION = '0.006';
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
use Number::Format                            qw(format_bytes);
use File::Spec::Functions                     qw(catfile);
use Data::AsObject                            qw(dao);
use Try::Tiny                                 qw(try catch);
use Module::Load                              qw(load);
use Data::Page                                qw();
use XML::TreePP                               qw();
use POSIX                                     qw(strftime);
use Miril::Error                              qw(process_error error_stack error);
use Miril::Util                               qw(
	get_target_filename
	get_last_modified_time
	get_latest
	add_to_latest
	generate_paged_url
	paginate
	load_tmpl
	prepare_authors
	prepare_statuses
	prepare_topics
	prepare_types
);

sub setup {
	my $self = shift;
	
	my $config_filename = $self->param('cfg_file');
	$config_filename = 'miril.config' unless $config_filename;


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
		'delete_files' => 'files_delete',
		'search'       => 'search',
		'login'        => 'login',
		'logout'       => 'logout',
		'account'      => 'account',
	);

	$self->start_mode('list');
	$self->error_mode('error');
	
	# load templates
	require Miril::Theme::Flashyweb;
	$self->{tmpl} = Miril::Theme::Flashyweb->new;
	
	# load configuration
	require Miril::Config;

	my $cfg;
	try {
		$cfg = Miril::Config->new($config_filename);
	} catch {
		$self->process_error("Could not open configuration file", $_, 'fatal');
	};
	return unless $cfg;

	$self->{cfg} = $cfg;

	
	# load model
	my $model_name = "Miril::Model::" . $self->cfg->model;
	try {
		load $model_name;
		$self->{model} = $model_name->new($self);
	} catch {
		$self->process_error("Could not load model", $_, 'fatal');
	};
	return unless $self->model;

	# load view
	my $view_name = "Miril::View::" . $self->cfg->view;
	try {
		load $view_name;
		$self->{view} = $view_name->new($self->cfg->tmpl_path);
	} catch {
		$self->process_error("Could not load view", $_, 'fatal');
	};

	# load filter
	my $filter_name = "Miril::Filter::" . $self->cfg->filter;
	try {
		load $filter_name;
		$self->{filter} = $filter_name->new($self->cfg);
	} catch {
		$self->process_error("Could not load filter", $_, 'fatal');
	};
	

	# load user manager
	my $user_manager_name = "Miril::UserManager::" . $self->cfg->user_manager;
	try {
		load $user_manager_name;
		$self->{user_manager} = $user_manager_name->new($self);
	} catch {
		$self->process_error("Could not load user manager", $_, 'fatal');
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

sub posts_list {
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

sub search {
	my $self = shift;

	my $cfg = $self->cfg;

	my $tmpl = $self->load_tmpl('search');

	$tmpl->param('statuses', $self->prepare_statuses );
	$tmpl->param('types',    $self->prepare_types    );
	$tmpl->param('topics',   $self->prepare_topics   ) if $cfg->topics;
	$tmpl->param('authors',  $self->prepare_authors  ) if $cfg->authors;

	return $tmpl->output;
}

sub posts_create {
	my $self = shift;

	my $cfg = $self->cfg;

	my $empty_item;

	$empty_item->{statuses} = $self->prepare_statuses;
	$empty_item->{types}    = $self->prepare_types;
	$empty_item->{authors}  = $self->prepare_authors if $cfg->authors;
	$empty_item->{topics}   = $self->prepare_topics  if $cfg->topics;

	my $tmpl = $self->load_tmpl('edit');
	$tmpl->param('item', $empty_item);
	
	return $tmpl->output;
}

sub posts_edit {
	my $self = shift;

	my $cfg = $self->cfg;

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

sub posts_update {
	my $self = shift;
	my $q = $self->query;

	my $item = {
		'id'     => $q->param('id'),
		'author' => $q->param('author'),
		'status' => $q->param('status'),
		'text'   => $q->param('text'),
		'title'  => $q->param('title'),
		'type'   => $q->param('type'),
		'old_id' => $q->param('old_id'),
	};

	$item->{topics} = [$q->param('topic')] if $q->param('topic');

	$self->model->save($item);

	return $self->redirect("?action=view&id=" . $item->{id});
}

sub posts_delete {
	my $self = shift;

	my $id = $self->query->param('old_id');
	$self->model->delete($id);

	return $self->redirect("?action=list");
}

sub posts_view {
	my $self = shift;
	
	my $q = $self->query;
	my $id = $q->param('old_id') ? $q->param('old_id') : $q->param('id');

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

		my $tmpl = $self->load_tmpl('account');
		$tmpl->param('user', $user);
		return $tmpl->output;
	} 
}

sub files_list {
	my $self = shift;

	my $cfg = $self->cfg;

	my $files_path = $cfg->files_path;
	my $files_http_dir = $cfg->files_http_dir;
	my @files;
	
	opendir(my $dir, $files_path) or $self->process_error("Cannot open files directory", $!, 'fatal');
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

sub files_upload {
	my $self = shift;
	my $q = $self->query;
	my $cfg = $self->cfg;

	if ( $q->param('file') or $q->upload('file') ) {
	
		my @filenames = $q->param('file');
		my @fhs = $q->upload('file');

		for ( my $i = 0; $i < @fhs; $i++) {

			my $filename = $filenames[$i];
			my $fh = $fhs[$i];

			if ($filename and $fh) {
				my $new_filename = catfile($cfg->files_path, $filename);
				my $new_fh = IO::File->new($new_filename, "w") 
					or $self->process_error("Could not upload file", $!);
				copy($fh, $new_fh) 
					or $self->process_error("Could not upload file", $!);
				$new_fh->close;
			}
		}

		return $self->redirect("?action=files");

	} else {
		
		my $tmpl = $self->load_tmpl('upload');
		return $tmpl->output;

	}
}

sub files_delete {
	my $self = shift;	
	my $cfg = $self->cfg;
	my $q = $self->query;

	my @filenames = $q->param('file');

	try {
		for (@filenames) {
			unlink( catfile($cfg->files_path, $_) )
				or $self->process_error("Could not delete file", $!);
		}
	};

	return $self->redirect("?action=files");
}

sub posts_publish {
	my $self = shift;

	my $cfg = $self->cfg;
	
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
				or $self->process_error("Cannot open file $new_filename for writing", $!);
			if ($fh) {
				$fh->print( $output )
					or $self->process_error("Cannot print to file $new_filename", $!);
				$fh->close;
			}
		}

		foreach my $list ($cfg->lists->list) {

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
				or $self->process_error("Cannot open file $new_filename for writing", $!);
			if ($fh) {
				$fh->print( $output )
					or $self->process_error("Cannot print to file $new_filename", $!);
				$fh->close;
			}

		}
		return $self->redirect("?action=list");
		
	} else {
		my $tmpl = $self->load_tmpl('publish');
		return $tmpl->output;
	}
}

### ACCESSORS ###

sub model        { shift->{model};        }
sub filter       { shift->{filter};       }
sub cfg          { shift->{cfg};          }
sub tmpl         { shift->{tmpl};         }
sub errors       { shift->{errors};       }
sub user_manager { shift->{user_manager}; }
sub pager        { shift->{pager};        }
sub view         { shift->{view};         }


1;

=head1 WARNING

This is alfa-quality software, use with great care!

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

