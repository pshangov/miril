package Miril::URL;

use strict;
use warnings;

use Object::Tiny qw(
	abs
	rel
	tag
);

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}

1;
