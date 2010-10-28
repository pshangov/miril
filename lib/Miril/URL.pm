package Miril::URL;

use strict;
use warnings;

use Mouse;

has 'abs' =>
(
	is => 'ro',
);

has 'rel' =>
(
	is => 'ro',
);

has 'tag' =>
(
	is => 'ro',
);

1;
