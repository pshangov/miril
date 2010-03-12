package Miril;

use warnings;
use strict;

use autodie;
use Try::Tiny;
use Exception::Class;

use Carp;
use Module::Load;

use Miril::Warning;
use Miril::Exception;
use Miril::Config;

our $VERSION = '0.007';

### ACCESSORS ###

use Object::Tiny qw(
	store
	tmpl
	cfg
	filter
	warnings
);

### CONSTRUCTOR ###

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	my $config_filename = shift;

	
	# load configuration
	try {
		my $cfg = Miril::Config->new($config_filename);
		$self->{cfg} = $cfg;
	} catch {
		Miril::Exception->throw( 
			errorvar => $_,
			message  => 'Could not open configuration file',
		);
	};
	return unless $self->cfg;

	# load store
	try {
		my $store_name = "Miril::Model::" . $self->cfg->model;
		load $store_name;
		my $store = $store_name->new($self);
		$self->{store} = $store;
	} catch {
		Miril::Exception->throw(
			errorvar => $_,
			message  => 'Could not load store',
		);
	};
	return unless $self->store;

	# load view
	try {
		my $view_name = "Miril::View::" . $self->cfg->view;
		load $view_name;
		$self->{view} = $view_name->new($self);
	} catch {
		Miril::Exception->throw(
			errorvar => $_,
			message  => 'Could not load view',
		);
	};

	# load filter
	try {
		my $filter_name = "Miril::Filter::" . $self->cfg->filter;
		load $filter_name;
		$self->{filter} = $filter_name->new($self->cfg);
	} catch {
		Miril::Exception->throw(
			errorvar => $_,
			message  => 'Could not load filter',
		);
	};
	
	return $self;
}

### PUBLIC METHODS ###

sub publish {
	my $miril = shift;
	my $rebuild = shift;

	my (@to_create, @to_update);

	my @posts = $miril->store->get_posts;

	foreach my $post (@posts) {
		my $src_modified = $post->modified_sec;

		my $target_filename = $miril->_get_target_filename($post->id, $post->type);
		
		if (-x $target_filename) {
			if ( $rebuild or ($src_modified > -M $target_filename) ) {
				push @to_update, $post->id;
			}
		} else {
			push @to_create, $post->id;
		}
	}

	for (@to_create, @to_update) {
		my $post = $miril->store->get_post($_);
		
		$post->text( $miril->filter->to_xhtml($post->text) );
		$post->teaser( $miril->filter->to_xhtml($post->teaser) );

		my $type = first {$_->id eq $post->type} $miril->cfg->types;
		
		my $output = $miril->tmpl->load(
			name => $type->template, 
			params => {
				item => $post,
				cfg => $miril->cfg,
		});

		my $new_filename = $miril->_get_target_filename($post->id, $post->type);
		$miril->_file_write($new_filename, $output);
	}

	foreach my $list ($miril->cfg->lists->list) {

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

		my @items = $miril->store->get_posts(%params);

		my $output = $miril->tmpl->load(
			name => $list->template,
			params => {
				items => \@items,
				cfg => $miril->cfg,
		});

		my $new_filename = catfile($miril->cfg->output_path, $list->location);
		$miril->_file_write($new_filename, $output);
	}
}

sub process_error {
	shift;
	carp(@_);
}

sub push_warning {
	my $self = shift;
	my ($miril_msg, $perl_msg) = @_;

	my $warnings_stack = $self->warnings;
	my $warning = Miril::Warning->new(
		message  => $miril_msg,
		errorvar => $perl_msg,
	);

	push @$warnings_stack, $warning;
}

### PRIVATE METHODS ###

sub _file_write {
	my ($self, $filename, $data) = @_;
	try {
		my $fh = IO::File->new($filename, "w");
		$fh->print($data);
		$fh->close;
	} catch {
		Miril::Exception->throw(
			errorvar => $_,
			message  => 'Could not save information',
		);
	}
}

sub _get_target_filename {
	my $self = shift;

	my $cfg = $self->miril->cfg;

	my ($name, $type) = @_;

	my $current_type = first {$_->id eq $type} $cfg->types;
	my $target_filename = catfile($cfg->output_path, $current_type->location, $name . ".html");

	return $target_filename;
}

1;

=head1 NAME

Miril - A Static Content Management System

=head1 VERSION

Version 0.007

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

