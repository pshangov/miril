use strict;
use warnings;

use Test::Most;

use Miril::Cache    qw();
use Miril::Post     qw();
use Miril::DateTime qw();
use Miril::Type     qw();
use Miril::Author   qw();
use Miril::Topic    qw();
use Miril::Taxonomy qw();
use Path::Class     qw(file dir);
use File::Temp      qw(tempfile);
use Devel::Dwarn    qw(Dwarn);

### SETUP ###

my ($fh, $filename) = tempfile;
close $fh or die $!;

my $source_path = file('t\data\aenean_eu_lorem');
my $data_dir = dir('t\data');

my $type = Miril::Type->new( 
    id       => 'news', 
    name     => 'News', 
    location => 'news', 
    template => 'news.tt',
);

my $author = Miril::Author->new( id => 'larry', name => 'Larry Wall' );
my $topic = Miril::Topic->new( id => 'perl', name => 'Perl' );
my $now = Miril::DateTime->now;

my $taxonomy = Miril::Taxonomy->new(
    authors => { larry => $author },
    topics  => { perl  => $topic  },
    types   => { news  => $type   },
);

my $post = Miril::Post->new(
    id          => 'aenean_eu_lorem',
    title       => 'Aenean Eu Lorem',
    modified    => $now,
    published   => $now,
    type        => $type,
    author      => $author,
    topics      => [$topic],
    source_path => $source_path,
);

### FRESH CACHE ###

my $cache = Miril::Cache->new( 
    filename    => file($filename),
    data_dir    => $data_dir,
    posts       => { aenean_eu_lorem => $post },
    taxonomy    => $taxonomy,
    base_url    => 'example.com',
    output_path => dir('.'),
);

isa_ok ( $cache, 'Miril::Cache' );
is_deeply ( [$cache->post_ids], ['aenean_eu_lorem'], "post ids" );

my $post_from_cache = $cache->get_post_by_id('aenean_eu_lorem');

isa_ok ( $post_from_cache, 'Miril::Post' );
is ( $post_from_cache->title, 'Aenean Eu Lorem', "post title" );
isa_ok ( $post_from_cache->type, 'Miril::Type', "post type" );

my $serialized = { aenean_eu_lorem => 
    {
        id          => 'aenean_eu_lorem',
        title       => 'Aenean Eu Lorem',
        modified    => $now,
        published   => $now,
        type        => $type,
        author      => $author,
        topics      => [$topic],
        source_path => $source_path,
    }
};

cmp_deeply ( $cache->serialize, $serialized, "serialization" );

ok ( $cache->update, "update" );

### PRIME CACHE ###

my $retrieved = Miril::Cache->new(
    filename => file($filename), 
    data_dir => $data_dir,
    taxonomy    => $taxonomy,
    base_url    => 'example.com',
    output_path => dir('.'),
);

isa_ok ( $retrieved, 'Miril::Cache' );

cmp_deeply ( $retrieved->raw, $serialized, "raw cache" );

$retrieved->posts;

is_deeply ( [$retrieved->post_ids], ['aenean_eu_lorem'], "post ids from cache" );

my $retrieved_from_cache = $cache->get_post_by_id('aenean_eu_lorem');

isa_ok ( $retrieved_from_cache, 'Miril::Post' );
is ( $retrieved_from_cache->title, 'Aenean Eu Lorem', "post title from cache" );
isa_ok ( $retrieved_from_cache->type, 'Miril::Type', "post type from cache" );

done_testing;
