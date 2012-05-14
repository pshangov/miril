package Miril::App::PSGI;

# ABSTRACT: Miril web UI as a PSGI application

use strict;
use warnings;

use Miril::CGI::Application;
use CGI::Application::Emulate::PSGI;

sub app {
	my ($self, $miril) = @_;
	return CGI::Application::Emulate::PSGI->handler( sub {
		my $app = Miril::CGI::Application->new(
			PARAMS => { miril => $miril },
		);
		$app->run;
	} );
}

1;
