#!perl

use strict;
use warnings;

use CGI::Application::Miril;

my $app = CGI::Application::Miril->new( PARAMS => 
	{ cfg_file => '../miril_example/cfg/config.xml' } 
);

$app->run
