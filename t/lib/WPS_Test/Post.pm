package WPS_Test::Post;

use strict;
use warnings;

use Any::Moose;
use Path::Class;

extends 'WWW::Publisher::Static::Post';

has 'id' =>
(
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has 'title' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'template' =>
(
	is      => 'ro',
	isa     => 'Str',
	default => 'test_template',
);

has 'path' =>
(
	is      => 'ro',
	isa     => 'Path::Class::File',
	default => sub { file( 'data', $_[0]->id . '.html' ) },
);

has 'is_dirty' =>
(
	is      => 'ro',
	isa     => 'Bool',
	default => 1,
);

no Any::Moose;

1;
