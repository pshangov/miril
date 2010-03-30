package App::PSGI::Miril;

use CGI::Application::PSGI;
use CGI::Application::Miril;

sub app {
	return sub {
		my $env = shift;
		my $miril = CGI::Application::Miril->new(
			QUERY => CGI::PSGI->new($env),
			PARAMS => { cfg_file => 'example/settings/cfg/config.xml' },
		);
		local $ENV{HTTP_COOKIE} = $env->{HTTP_COOKIE};
		CGI::Application::PSGI->run($miril);
	};
}

1;
