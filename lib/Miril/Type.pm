package Miril::Type;

use strict;
use warnings;

use Mouse;

has 'id' =>
(
	is => 'ro',
);

has 'name' =>
(
	is => 'ro',
);

has 'location' =>
(
	is => 'ro',
);

has 'template' =>
(
	is => 'ro',
);

1;
