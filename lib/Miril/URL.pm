package Miril::URL;

use strict;
use warnings;

use Object::Tiny qw(
	abs
	rel
);

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}

1;
