package Miril::View::Abstract;

use strict;
use warnings;

sub new {
	my $class = shift;
	my $tmpl_path = shift;

	my $self = bless {}, $class;

	$self->{tmpl_path} = $tmpl_path;

	return $self;
}

sub tmpl_path {shift->{tmpl_path}}

1;
