package Miril::Model::File::Post;

use strict;
use warnings;

use base 'Miril::Post';

sub body {
	my $self = shift;

	if ($self->{body}) {
		return $self->{body};
	} else {
		...
	}
}

1;
