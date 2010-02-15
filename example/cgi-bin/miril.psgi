use CGI::Application::PSGI;
use Miril;

my $app = sub {
    my $env = shift;
    my $app = Miril->new(
		QUERY => CGI::PSGI->new($env),
		PARAMS => { miril_dir => '../settings/cfg/config.xml' },
	);
    CGI::Application::PSGI->run($app);
};

