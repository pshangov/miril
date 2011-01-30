package WPS_Test::Post;

use strict;
use warnings;

use Any::Moose;
use Path::Class;

extends 'WWW::Publisher::Static::Post';

has 'id' =>
(
	is  => 'ro',
	isa => 'Str',
	required => 1,
);

has 'title' =>
(
	is  => 'ro',
	isa => 'Str',
);

has '+template' =>
(
	default => 'test_template',
);

has '+path' =>
(
	lazy    => 1,
	default => sub { file( 'data', $_[0]->id . '.html' ) },
);

has 'type' =>
(
	is       => 'ro',
	isa      => 'Str',
);

no Any::Moose;

1;
