#!perl

use FindBin;
use File::Spec;
use Module::Load;
use Data::Dumper;

use Test::More tests => 3;

my %formats = (
	conf => 'Config::General',
	yaml => 'YAML',
	xml  => 'XML',
);

foreach my $format ( keys %formats )
{
	my $class = "Miril::Config::Format::" . $formats{$format};
	Module::Load::load($class);
	my $config_filename = File::Spec->catfile( 
		$FindBin::Bin, 
		'config',
		'miril.' . $format,
	);
	my $config = $class->new($config_filename);
	isa_ok($config, 'Miril::Config');
}
