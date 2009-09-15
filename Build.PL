use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Miril',
    license             => 'perl',
    dist_author         => q{Peter Shangov <pshangov@yahoo.com>},
    dist_version_from   => 'lib/Miril.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Miril-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
