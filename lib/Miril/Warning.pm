package Miril::Warning;

# ABSTRACT: Base class for warnings displayed in the UI

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
