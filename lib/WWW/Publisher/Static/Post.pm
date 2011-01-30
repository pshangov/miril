package WWW::Publisher::Static::Post;

use strict;
use warnings;

use Any::Moose;

has 'template' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'path' =>
(
	is  => 'ro',
	isa => 'Path::Class::File',
);

no Any::Moose;

1;
