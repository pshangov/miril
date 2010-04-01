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

sub status {
	my $self = shift;
	my $status = $self->published ? 'published' : 'draft';
	return $status;
}

sub _populate {
	my $self = shift;
	
	my $post_file;
	try {
		$post_file = File::Slurp::read_file($self->filename);
	} catch {
		Miril::Exception->throw(
			message => "Cannot load data file",
			errorvar => $_,
		);
	};

	my ($meta, $body) = split( /\n\n/, $post_file, 2);
	my ($teaser)      = split( '<!-- END TEASER -->', $body, 2);

	$self->{body} = $body;
	$self->{teaser} = $teaser;
}

1;
