use strict;
use warnings;

use Test::Most;

use Miril::Cache;
use Miril::Post;
use Miril::DateTime;
use Miril::Type;
use Miril::Taxonomy;
use Miril::Field::Option;
use Path::Class  qw(file dir);
use File::Temp   qw(tempfile);

### SETUP ###

my ($fh, $filename) = tempfile;
close $fh or die $!;

my $source_path = file(qw(t data aenean_eu_lorem));
my $data_dir = dir(qw(t data));

my $type = Miril::Type->new( 
    id       => 'news', 
    name     => 'News', 
    location => 'news/%(id)s.html', 
    template => 'news.tt',
);

my $author = Miril::Field::Option->new(
	id      => 'author',
	name    => 'Author',
	options => { larry  => 'Larry Wall' },
);

my $topic = Miril::Field::Option->new(
	id       => 'topic',
	name     => 'Topics',
	multiple => 1,
	options  => { perl   => 'Perl' },
);

my $now = Miril::DateTime->now;

my $taxonomy = Miril::Taxonomy->new(
    types  => { news  => $type   },
    fields => { author => $author, topic => $topic },
);

my %fields = (
    author => $taxonomy->field('author')->process('larry'),
    topic  => $taxonomy->field('topic')->process('perl'),
);

my $post = Miril::Post->new(
    id          => 'aenean_eu_lorem',
    title       => 'Aenean Eu Lorem',
    modified    => $now,
    published   => $now,
    topics      => [$topic],
    source_path => $source_path,
    type        => $type,
    fields      => \%fields,
);

### FRESH CACHE ###

my $cache = Miril::Cache->new( 
    filename    => file($filename),
    data_dir    => $data_dir,
    posts       => { aenean_eu_lorem => $post },
    taxonomy    => $taxonomy,
    base_url    => 'example.com',
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
        fields      => \%fields,
        source_path => $source_path,
    }
};

cmp_deeply ( $cache->serialize, $serialized, "serialization" );

ok ( $cache->update, "update" );

### PRIME CACHE ###

my $retrieved = Miril::Cache->new(
    filename    => file($filename), 
    data_dir    => $data_dir,
    taxonomy    => $taxonomy,
    base_url    => 'example.com',
);

isa_ok ( $retrieved, 'Miril::Cache' );
cmp_deeply ( $retrieved->raw, $serialized, "raw cache" );
is_deeply ( [$retrieved->post_ids], ['aenean_eu_lorem'], "post ids from cache" );

my $retrieved_from_cache = $cache->get_post_by_id('aenean_eu_lorem');

isa_ok ( $retrieved_from_cache, 'Miril::Post' );
is ( $retrieved_from_cache->title, 'Aenean Eu Lorem', "post title from cache" );
isa_ok ( $retrieved_from_cache->type, 'Miril::Type', "post type from cache" );

done_testing;
