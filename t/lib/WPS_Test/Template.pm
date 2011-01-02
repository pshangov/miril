package WPS_Test::Template;

use strict;
use warnings;

use Any::Moose;

use Data::Dumper qw(Dumper);

sub load
{
	my ( $self, %params ) = @_;
	return Dumper $params{params};
}

1;
