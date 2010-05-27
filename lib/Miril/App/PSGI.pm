package Miril::App::PSGI;

use strict;
use warnings;
use autodie;

use Miril::CGI::Application;
use CGI::Application::Emulate::PSGI;

sub app {
	return CGI::Application::Emulate::PSGI->handler( sub {
		my $miril = Miril::CGI::Application->new(
			PARAMS => { 
				miril_dir => 'example',
				site      => 'example.com',
			},
		);
		$miril->run;
	} );
}

1;
