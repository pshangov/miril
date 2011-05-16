package Miril;

use warnings;
use strict;
use autodie;

use Try::Tiny;
use Exception::Class;
use Carp;
use Module::Load;
use Ref::List qw(list);
use Miril::Warning;
use Miril::Exception;
use Miril::Config;
use Miril::Util;

use Mouse;

our $VERSION = '0.008';

has 'miril_dir' =>
(
	is       => 'ro',
	required => 1,
);

has 'site' =>
(
	is       => 'ro',
	required => 1,
);

has 'cfg' =>
(
	is      => 'ro',
	isa     => 'Miril::Config',
	lazy    => 1,
	builder => sub { 
		Miril::Config->new( miril_dir => $_[0]->miril_dir, site => $_[0]->site );
	},
);

has 'util' =>
(
	is      => 'ro',
	isa     => 'Miril::Util',
	lazy    => 1,
	builder => sub {
		Miril::Util->new( cfg => $_[0]->cfg )
	},
);

has 'store' =>
(
	is      => 'ro',
	isa     => 'Miril::Store',
	lazy    => 1,
	builder => sub 
	{
		my $self = shift;
		my $store_name = "Miril::Store::" . $self->cfg->store;
		Module::Load::load $store_name;
		return $store_name->new( cfg => $_[0]->cfg, util => $_[0]->util );
	},
);

has 'tmpl' =>
(
	is      => 'ro',
	isa     => 'Miril::Template',
	lazy    => 1,
	builder => sub 
	{
		my $self = shift;
		my $template_name = "Miril::Template::" . $self->cfg->template;
		Module::Load::load $template_name;
		return $template_name->new;
	},
);

has 'warnings' =>
(
	traits  => ['Array'],
	is      => 'rw',
	isa     => 'ArrayRef[Miril::Warning]',
	default => sub { [] },
	handles => {
    	push_warning => 'push',
	},
);

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

