use strict;
use warnings;

use Test::Most;
use Path::Class qw(dir);
use Miril;

my $base_dir = dir(qw(t example.com));

my $miril = Miril->new( base_dir => $base_dir );

isa_ok($miril,           'Miril'          );
isa_ok($miril->config,   'Miril::Config'  );
isa_ok($miril->taxonomy, 'Miril::Taxonomy');
isa_ok($miril->cache,    'Miril::Cache'   );
isa_ok($miril->store,    'Miril::Store'   );

done_testing;
