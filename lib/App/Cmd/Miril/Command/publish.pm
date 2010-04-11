package App::Cmd::Miril::Command::publish;

use strict;
use warnings;

use App::Cmd::Miril -command;

use Class::Autouse;
Class::Autouse->autouse('Miril');

sub execute {
	my ($self, $opt, $args) = @_;
	
	my $miril = Miril->new('../miril_example/cfg/config.xml');
	$miril->publish;
}

1;
