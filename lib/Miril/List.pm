package Miril::List;

use strict;
use warnings;

use Mouse;

extends 'WWW::Publisher::Static::List';

has 'timestamp' =>
(
	qw(:ro :lazy),
	default => sub { Miril::DateTime->new(time()) },
);

sub get_post_by_id
{
	my $self = shift;
	my $id = shift;

	return first { $_ eq $id } list $self->posts;
}

1;
