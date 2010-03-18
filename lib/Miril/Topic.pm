package Miril::Topic;

use strict;
use warnings;

use Object::Tiny qw(
	id
	name
);

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}

1;
