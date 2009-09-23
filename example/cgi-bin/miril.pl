#!perl

use strict;
use warnings;

use Miril;

my $app = Miril->new( PARAMS => { cfg_file => '../miril_example/cfg/config.xml' } );
$app->run
