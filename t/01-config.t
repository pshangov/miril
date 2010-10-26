#!perl

use FindBin;
use File::Spec;
use Module::Load;
use Data::Dumper;

use Test::More tests => 1;

#my $miril_dir = File::Spec->catdir( $FindBin::Bin, '..', 'example' );
#my $site = 'example.com';

my $config_filename = File::Spec->catfile( 
	$FindBin::Bin, 
	'config',
	'miril.conf',
);

foreach my $format (qw(Config::General))
{
	my $class = "Miril::Config::Format::$format";
	Module::Load::load($class);
	my $config = $class->new($config_filename);
	print Dumper $config;
	#isa_ok($config, 'Miril::Config');
}
