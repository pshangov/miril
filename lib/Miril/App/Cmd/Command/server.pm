package Miril::App::Cmd::Command::server;

# ABSTRACT: Run the web UI on a local server

use strict;
use warnings;
use autodie;

use Miril::App::Cmd -command;

use Class::Autouse;
Class::Autouse->autouse('Plack::Loader');
Class::Autouse->autouse('Plack::Middleware::Static');
Class::Autouse->autouse('Miril::App::PSGI');
Class::Autouse->autouse('File::Spec');

sub opt_spec
{
	return (
		[ 'host|h=s',    "host address to bind to",    { default => 'localhost' }   ],
		[ 'port|p=i',    "port to listen on",          { default => 8080 }          ],
	);
}

sub execute 
{
	my ($self, $opt, $args) = @_;

    my $app = Miril::App::PSGI->app($self->miril);

    if ( my $static = $self->miril->config->static ) {
        $static = join '/', File::Spec->splitdir($static); # normalize
        $app = Plack::Middleware::Static->wrap($app,
            path => qr{^/$static/}, root => $self->miril->config->output_path
        );
    }

	print "Miril accepting connections at http://" . $opt->host . ":" . $opt->port ."\n";

	Plack::Loader->auto(
		host => $opt->host,
		port => $opt->port,
	)->run($app);
}

1;

