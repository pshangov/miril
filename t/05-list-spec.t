use strict;
use warnings;

use Test::Most;

use Miril::List::Spec;

my $match = { type => 'blog' };
my $map = { name => 'Article Archive', template => 'archive.tmpl', location => 'archive.html' };

my $list_spec = Miril::List::Spec->new(
    id       => 'by_month',
    name     => 'Monthly Archive',
    group    => 'month',
    template => 'by_month.html',
    page     => 10,
    location => 'archive/%(year)d/%(month)02d.html',
    match    => $match,
    map      => $map,
);

isa_ok( $list_spec, 'Miril::List::Spec' );

is( $list_spec->id,           'by_month',                          'id'           );
is( $list_spec->name,         'Monthly Archive',                   'name'         );
is( $list_spec->group,        'month',                             'group'        );
is( $list_spec->template,     'by_month.html',                     'template'     );
is( $list_spec->page,         10,                                  'page'         );
is( $list_spec->location,     'archive/%(year)d/%(month)02d.html', 'location'     );
is( $list_spec->map_name,     'Article Archive',                   'map name'     );
is( $list_spec->map_template, 'archive.tmpl',                      'map template' );
is( $list_spec->map_location, 'archive.html',                      'map location' );

ok( $list_spec->is_grouped, 'group predicate' );
ok( $list_spec->is_paged,   'page predicate'  );
ok( $list_spec->has_map,    'map predicate'   );

is_deeply( $list_spec->match, $match, 'match' );
is_deeply( $list_spec->map,   $map,   'map'   );

done_testing;
