package Miril::Type;

use strict;
use warnings;

use Mouse;
use Miril::TypeLib qw(TextId Str);

has 'id' =>
(
	is       => 'ro',
	isa      => TextId,
	required => 1,
);

has 'name' =>
(
	is       => 'ro',
	isa      => Str,
	required => 1,
);

has 'location' =>
(
	is => 'ro',
	isa      => Str,
	required => 1,
);

has 'template' =>
(
	is       => 'ro',
	isa      => Str,
	required => 1,
);

1;
