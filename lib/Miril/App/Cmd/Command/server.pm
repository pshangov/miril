package Miril::App::Cmd::Command::server;

use strict;
use warnings;

use Miril::App::Cmd -command;

use Class::Autouse;
Class::Autouse->autouse('Plack::Runner');
Class::Autouse->autouse('Miril::App::PSGI');

sub execute {
	my ($self, $opt, $args) = @_;

	my $runner = Plack::Runner->new;
	$runner->run(Miril::App::PSGI->app);
}

1;

