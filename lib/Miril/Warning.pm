package Miril::Warning;

use strict;
use warnings;

use Mouse;

has 'errorvar' =>
(
	is => 'ro',
);

has 'message' =>
(
	is => 'ro',
);

1;
