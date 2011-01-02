package WWW::Publisher::Static::Post;

use strict;
use warnings;

use Any::Moose;

has 'id' =>
(
	is  => 'ro',
	isa => 'Str',
);


has 'template' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'path' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'is_dirty' =>
(
	is  => 'ro',
	isa => 'Bool',
);

no Any::Moose;

1;
