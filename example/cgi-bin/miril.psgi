use CGI::Application::PSGI;
use Miril;

my $app = sub {
    my $env = shift;
    my $app = Miril->new(
		QUERY => CGI::PSGI->new($env),
		PARAMS => { cfg_file => '../settings/cfg/config.xml' },
	);
    CGI::Application::PSGI->run($app);
};

