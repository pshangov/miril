package Miril::App::PSGI;

use strict;
use warnings;
use autodie;

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
