package Miril::Model::File::Post;

use strict;
use warnings;

use autodie;
use Try::Tiny;
use Miril::Exception;

use File::Spec;

use base 'Miril::Post';

sub body {
	my $self = shift;

	if ($self->{body}) {
		return $self->{body};
	} else {
		$self->_populate;
		return $self->{body};
	}
}

sub teaser {
	my $self = shift;

	if ($self->{teaser}) {
		return $self->{teaser};
	} else {
		$self->_populate;
		return $self->{teaser};
	}
}

sub _populate {
	my $self = shift;
	
	try {
		my $post_file = File::Slurp::read_file($self->filename);
	} catch {
		##
	}

	my ($meta, $body) = split( '<!-- END META -->', $post_file, 2);
	my ($teaser)      = split( '<!-- END TEASER -->', $body, 2);

	$self->{body} = $body;
	$self->{teaser} = $teaser;
}

1;
