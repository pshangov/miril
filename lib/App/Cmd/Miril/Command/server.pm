package App::Cmd::Miril::Command::server;

use strict;
use warnings;

use App::Cmd::Miril -command;

use Class::Autouse;
Class::Autouse->autouse('Plack::Runner');
Class::Autouse->autouse('App::PSGI::Miril');

sub execute {
	my ($self, $opt, $args) = @_;

	my $runner = Plack::Runner->new;
	$runner->run(App::PSGI::Miril->app);
}

1;

