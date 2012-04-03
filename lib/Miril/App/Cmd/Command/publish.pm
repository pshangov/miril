package Miril::App::Cmd::Command::publish;

# ABSTRACT: Publish the site

use strict;
use warnings;
use autodie;

use Miril::App::Cmd -command;

use Class::Autouse;
Class::Autouse->autouse('Miril');

sub opt_spec
{
	return (
		[ 'dir|d=s',     "miril base dir" ],
		[ 'site|s=s',    "website",       ],
	);
}

sub execute 
{
	my ($self, $opt, $args) = @_;
	$self->miril->publisher->publish;
}

1;
