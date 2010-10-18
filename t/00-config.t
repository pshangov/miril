#!perl

use FindBin;
use File::Spec::Functions qw(catdir);
use Miril::Config;
use Data::Dumper;

#use Test::More tests => 1;
use Test::More;

my $miril_dir = catdir( $FindBin::Bin, '..', 'example' );
my $site = 'example.com';

my $config = Miril::Config->new($miril_dir, $site);

print Dumper $config;
