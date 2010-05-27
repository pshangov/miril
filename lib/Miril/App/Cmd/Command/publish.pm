package Miril::App::Cmd::Command::publish;

use strict;
use warnings;
use autodie;

use Miril::App::Cmd -command;

use Class::Autouse;
Class::Autouse->autouse('Miril');

sub execute {
	my ($self, $opt, $args) = @_;
	
	my $miril = Miril->new('example', 'example.com');
	$miril->publish;
}

1;
