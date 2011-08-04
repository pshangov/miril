package Miril::App::Cmd::Command::preview;

use strict;
use warnings;

use Miril::App::Cmd -command;
use Plack::App::File;
use Plack::Loader;

sub opt_spec
{
	return (
        [ 'dir|d=s',     "website directory"                                        ],
		[ 'host|h=s',    "host address to bind to",    { default => 'localhost' }   ],
		[ 'port|p=i',    "port to listen on",          { default => 8080 }          ],
	);
}

sub execute 
{
	my ($self, $opt, $args) = @_;
	
    my $directory = $self->miril->config->output_path;
    my $app = Plack::App::File->new( root => $directory )->to_app;

    print "Preview of " . $self->miril->config->name . " at http://" . $opt->{host} . ":" . $opt->{port} ."\n";

    Plack::Loader->auto(
		host => $opt->{host},
		port => $opt->{port},
	)->run($app);
}

1;

