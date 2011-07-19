package Miril;

use warnings;
use strict;
use autodie;

use Try::Tiny;
use Exception::Class;
use Carp;
use Module::Load;
use Ref::List qw(list);
use Path::Class qw(file dir);
use Miril::Warning;
use Miril::Exception;
use Miril::Config;
use Miril::Taxonomy;
use Miril::Cache;
use Miril::Store;
use Miril::Publisher;
use Miril::Template;
use Miril::Util;
use Class::Load qw(load_class);
use Hash::MoreUtils qw(slice_def);
use List::MoreUtils qw(apply);

use Mouse;

our $VERSION = '0.008';

has 'base_dir' =>
(
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'config' =>
(
	is       => 'ro',
	isa      => 'Miril::Config',
	required => 1,
    builder  => '_build_config',
);

has 'config_filename' =>
(
	is  => 'rw',
	isa => 'Path::Class::File',
);

has 'cache' =>
(
	is         => 'ro',
	isa        => 'Miril::Cache',
	lazy_build => 1,
);

has 'taxonomy' =>
(
    is         => 'ro',
	isa        => 'Miril::Taxonomy',
	lazy_build => 1,
);

has 'store' =>
(
	is         => 'ro',
	isa        => 'Miril::Store',
	lazy_build => 1,
);

has 'template' =>
(
	is         => 'ro',
	isa        => 'Miril::Template',
	lazy_build => 1,
);

has 'warnings' =>
(
	traits    => ['Array'],
	is        => 'rw',
	isa       => 'ArrayRef[Miril::Warning]',
	default   => sub { [] },
	handles   => {
    	push_warning    => 'push',
    	has_no_warnings => 'is_empty',
	},
);

has 'publisher' => 
(
    is         => 'ro',
    isa        => 'Miril::Publisher',
    lazy_build => 1,

);

sub _build_base_dir
{
    return dir('.');
}

sub _build_config
{
    my $self = shift;

    my %extensions = (
        'miril.xml'  => 'Miril::Config::Format::XML',
        'miril.conf' => 'Miril::Config::Format::Config::General',
        'miril.yaml' => 'Miril::Config::Format::YAML',
    );

    my @files = grep { -e } map { file($self->base_dir, $_) } keys %extensions;

    my $config_filename = shift @files;
    warn "Multiple configuration files found!" if @files;

    my $class = $extensions{$config_filename->basename};
    load_class $class;
    $self->config_filename(file($config_filename));

    return $class->new($config_filename);
}

sub _build_store
{
    my $self = shift;

    return Miril::Store->new( 
        taxonomy => $self->taxonomy,
        cache    => $self->cache,
        data_dir => $self->config->data_path,
    );
}

sub _build_taxonomy
{
    my $self = shift;

    return Miril::Taxonomy->new( slice_def {
        authors => $self->config->authors, 
        topics  => $self->config->topics, 
        types   => $self->config->types,
    } );
}

sub _build_cache
{
    my $self = shift;
    
    return Miril::Cache->new(
        filename    => $self->config->cache_path, 
        data_dir    => $self->config->data_path,
        output_path => dir($self->config->output_path),
        taxonomy    => $self->taxonomy,
        base_url    => $self->config->base_url,
    );
}

sub _build_publisher
{
    my $self = shift;

    my @lists = apply { 
        $_->posts([$self->store->search($_->search_options)])
    } $self->config->get_lists;

    my @posts = $self->store->get_posts;

    return Miril::Publisher->new(
        posts       => \@posts,
        lists       => \@lists,
        groups      => $self->config->groups,
        template    => $self->template,
        output_path => dir($self->config->output_path),
    );
}

sub _build_template
{
    my $self = shift;

    return Miril::Template->new( 
        config => { INCLUDE_PATH => dir($self->base_dir, 'templates')->stringify }, 
    );
}

1;

=head1 NAME

Miril - A Static Content Management System

=head1 VERSION

Version 0.008

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

