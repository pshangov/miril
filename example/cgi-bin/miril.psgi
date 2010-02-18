use CGI::Application::PSGI;
use CGI::Application::Miril;

my $app = sub {
    my $env = shift;
    my $miril = CGI::Application::Miril->new(
		QUERY => CGI::PSGI->new($env),
		PARAMS => { cfg_file => 'example/settings/cfg/config.xml' },
	);
	$ENV{HTTP_COOKIE} = $env->{HTTP_COOKIE};
	CGI::Application::PSGI->run($miril);
};

