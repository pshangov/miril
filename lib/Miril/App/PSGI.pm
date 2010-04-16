package Miril::App::PSGI;

use CGI::Application::PSGI;
use Miril::CGI::Application;

sub app {
	return sub {
		my $env = shift;
		my $miril = Miril::CGI::Application->new(
			QUERY => CGI::PSGI->new($env),
			PARAMS => { 
				miril_dir => 'example',
				site      => 'example.com',
			},
		);
		$ENV{HTTP_COOKIE} = $env->{HTTP_COOKIE};
		CGI::Application::PSGI->run($miril);
	};
}

1;
