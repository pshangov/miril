package Miril;

use warnings;
use strict;

=head1 NAME

Miril - A Static Content Management System

=head1 VERSION

Version 0.007

=cut

our $VERSION = '0.007';
$VERSION = eval $VERSION;

### ACCESSORS ###

use Object::Tiny qw(
	store
	tmpl
	cfg
	util
);

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	my $config_filename = shift;
	
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
		$self->store( $model_name->new($self) );
	} catch {
		$self->process_error("Could not load model", $_, 'fatal');
	};
	return unless $self->model;

	# load view
	my $view_name = "Miril::View::" . $self->cfg->view;
	try {
		load $view_name;
		$self->{view} = $view_name->new($self);
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
	
	return $self;
}

sub publish {
	my $miril = shift;
	my $rebuild = shift;

	my (@to_create, @to_update);

	my @posts = $miril->store->get_posts;

	foreach my $post (@posts) {
		my $src_modified = $post->modified_sec;

		my $target_filename = $miril->util->get_target_filename($post->id, $post->type);
		
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

		my $new_filename = $miril->util->get_target_filename($post->id, $post->type);

		my $fh = IO::File->new($new_filename, "w") 
			or $miril->process_error("Cannot open file $new_filename for writing", $!);
		if ($fh) {
			$fh->print( $output )
				or $miril->process_error("Cannot print to file $new_filename", $!);
			$fh->close;
		}
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

		my @items = $miril->store->get_posts( %params );

		my $output = $miril->tmpl->load(
			name => $list->template,
			params => {
				items => \@items,
				cfg => $miril->cfg,
		});

		my $new_filename = catfile($miril->cfg->output_path, $list->location);

		my $fh = IO::File->new($new_filename, "w") 
			or $miril->process_error("Cannot open file $new_filename for writing", $!);
		if ($fh) {
			$fh->print( $output )
				or $miril->process_error("Cannot print to file $new_filename", $!);
			$fh->close;
		}

	}
}

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

