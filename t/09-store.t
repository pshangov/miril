use strict;
use warnings;

use Test::Most;
use Path::Class qw(file dir);
use File::Temp  qw(tempdir);
use Miril::Field::Option;
use Miril::Type;
use Miril::Taxonomy;
use Miril::DateTime;
use Miril::Post;
use Miril::Cache;
use Miril::Store;

#########
# SETUP #
#########

### TAXONOMY ###

my $authors = Miril::Field::Option->new(
	id      => 'author',
	name    => 'Author',
	options => {
		larry  => 'Larry Wall',
		damian => 'Damian Conway',
	},
);

my $topics = Miril::Field::Option->new(
	id       => 'topic',
	name     => 'Topics',
	multiple => 1,
	options  => {
		perl   => 'Perl',
		python => 'Python',
		ruby   => 'Ruby',
	},
);

my $type = Miril::Type->new(
	id       => 'news',
	name     => 'News',
	location => 'somewhere',
	template => 'some_template',
	fields   => [qw(topic author)],
);

my $taxonomy = Miril::Taxonomy->new( 
    types  => { news => $type },
    fields => { author => $authors, topic => $topics },
);

### CACHE ###

my $now = Miril::DateTime->now;
my $dummy_file = file('dummy_file');
my $dummy_dir  = dir('dummy_dir');

my %posts = (
    aenean_eu_lorem => Miril::Post->new(
        id          => 'aenean_eu_lorem',
        title       => 'Aenean Eu Lorem',
        modified    => $now,
        published   => $now,
        type        => $type,
        fields      => {
            author => $taxonomy->field('author')->process('larry'),
            topic  => $taxonomy->field('topic')->process('perl'),
        },
        source_path => $dummy_file, 
    ),
    lorem_ipsum_dolor => Miril::Post->new(
        id          => 'lorem_ipsum_dolor',
        title       => 'Lorem Ipsum Dolor',
        modified    => $now,
        published   => $now,
        type        => $type,
        fields      => {
            author => $taxonomy->field('author')->process('damian'),
            topic  => $taxonomy->field('topic')->process('python'),
        },
        source_path => $dummy_file, 
    ),
);
    
my $cache = Miril::Cache->new(
    filename    => $dummy_file, 
    data_dir    => $dummy_dir,
    posts       => \%posts,
    taxonomy    => $taxonomy,
    base_url    => 'example.com',
    output_path => dir('.'),
);

### STORE ###

my $data_dir = dir( tempdir( CLEANUP => 1 ) );

my $store = Miril::Store->new(
    cache    => $cache,
    taxonomy => $taxonomy,
    data_dir => $data_dir,
);

#########
# TESTS #
#########

### POSTS ###

isa_ok ($store, 'Miril::Store');
is_deeply ( [ sort $store->post_ids ], [ qw(aenean_eu_lorem lorem_ipsum_dolor) ], "post ids" );

my $post_from_store = $store->get_post_by_id('aenean_eu_lorem');

isa_ok ( $post_from_store, 'Miril::Post' );
is ( $post_from_store->title, 'Aenean Eu Lorem', "post title" );
isa_ok ( $post_from_store->type, 'Miril::Type', "post type" );

### SEARCH ###

my @results_title  = map { $_->id } $store->search( title  => 'aenean' );

my @results_type   = sort map { $_->id } $store->search( type  => 'news' );
my @results_limit  = $store->search( limit => 1 );

my @results_complex = map { $_->id } $store->search(
    title  => 'aenean',
    type   => 'news',
    author => 'larry',
    limit  => 10,
    sort   => 'published',
);

my @results_not_found = map { $_->id } $store->search(
    title  => 'kaboom',
);

is_deeply ( \@results_title,     ['aenean_eu_lorem'],                     'search by id' );
is_deeply ( \@results_complex,   ['aenean_eu_lorem'],                     'complex search' );
is_deeply ( \@results_type,      [qw(aenean_eu_lorem lorem_ipsum_dolor)], 'search by type' );
is_deeply ( \@results_not_found, [],                                      'search not found' );

is ( scalar @results_limit, 1, 'limit search' );

### CONTENT ###

my $source = <<EndOfSource;
Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.
EndOfSource

my $date_published = $now->as_ymdhm;

my $expected_content = <<EndOfSource;
Title: Aenean Eu Lorem
Type: news
Published: $date_published
Topics: perl
Author: larry

Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.
EndOfSource

my $post_content = Miril::Post->new(
    id          => 'aenean_eu_lorem',
    title       => 'Aenean Eu Lorem',
    modified    => $now,
    published   => $now,
    type        => $type,
    source_path => $dummy_file, 
    source      => $source,
    fields      => {
        author => $taxonomy->field('author')->process('larry'),
        topic  => $taxonomy->field('topic')->process('perl'),
    },
);

my $content = Miril::Store::_generate_content($post_content, $taxonomy);

eq_or_diff($content, $expected_content, 'generate content');

### SAVE ###

my $source_save = <<EndOfSource;
Etiam rhoncus.
<!-- BREAK -->
Maecenas tempus, tellus eget condimentum rhoncus, sem quam semper libero, sit amet adipiscing sem neque sed ipsum.
EndOfSource

my $id_to_save = 'etiam_rhoncus';

my %params = (
    id     => $id_to_save,
    title  => 'Etiam Rhoncus',
    author => 'larry',
    topic  => ['perl'],
    type   => 'news',
    status => 'published',
    source => $source_save,
);

ok ( $store->save(%params), 'save' );


my $new_post = $store->get_post_by_id($id_to_save);
my $saved_file = file($data_dir, $id_to_save);
my $saved_file_content = $saved_file->slurp;
my $date_saved = $new_post->published->as_ymdhm;

my $expected_file_content = <<EndOfContent;
Title: Etiam Rhoncus
Type: news
Published: $date_saved
Topics: perl
Author: larry

Etiam rhoncus.
<!-- BREAK -->
Maecenas tempus, tellus eget condimentum rhoncus, sem quam semper libero, sit amet adipiscing sem neque sed ipsum.
EndOfContent

isa_ok ( $new_post, 'Miril::Post' );
is ($new_post->title, 'Etiam Rhoncus', 'saved post title' );
eq_or_diff ( $saved_file_content, $expected_file_content, 'saved post content' );

### DELETE ###

ok ( $store->delete($id_to_save),           'delete post' );
ok ( ! $store->get_post_by_id($id_to_save), 'deleted post not in store' );
ok ( ! -e $saved_file->stringify,           'deleted post not in file system' );

done_testing;
