#!perl

use FindBin;
use File::Spec;
use Miril::Config::Format::Config::General;

use Test::More;

my $config_filename = File::Spec->catfile( 
    $FindBin::Bin, 
    'config',
    'miril.conf'
);

my $config = Miril::Config::Format::Config::General->new($config_filename);

is ($config->sync, 'echo "Syncing OK"', "sync option set");

done_testing;
