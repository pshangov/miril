use strict;
use warnings;

use Test::Most;
use Path::Class qw(file dir);

use Miril::Author;
use Miril::Topic;
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

my %authors = map { $_->[0] => Miril::Author->new(
	id   => $_->[0],
	name => $_->[1],
)} [ larry => 'Larry Wall' ], [ damian => 'Damian Conway'];

my %topics = map { $_->[0] => Miril::Topic->new(
	id   => $_->[0],
	name => $_->[1],
)} [ perl => 'Perl' ], [ python => 'Python'], [ ruby => 'Ruby' ];

my $type = Miril::Type->new(
	id       => 'news',
	name     => 'News',
	location => 'somewhere',
	template => 'some_template',
);

my $taxonomy = Miril::Taxonomy->new( 
    authors => \%authors, 
    topics  => \%topics, 
    types   => { news => $type },
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
        author      => $authors{larry},
        topics      => [$topics{perl}],
        source_path => $dummy_file, 
    ),
    lorem_ipsum_dolor => Miril::Post->new(
        id          => 'lorem_ipsum_dolor',
        title       => 'Lorem Ipsum Dolor',
        modified    => $now,
        published   => $now,
        type        => $type,
        author      => $authors{damian},
        topics      => [$topics{python}],
        source_path => $dummy_file, 
    ),
);
    
my $cache = Miril::Cache->new(
    filename => $dummy_file, 
    data_dir => $dummy_dir,
    posts    => \%posts,
);

### STORE ###

my $store = Miril::Store->new(
    cache    => $cache,
    taxonomy => $taxonomy,
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
my @results_author = map { $_->id } $store->search( author => 'damian' );
my @results_topic  = map { $_->id } $store->search( topic  => 'perl' );

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
    title  => 'aenean',
    author => 'damian',
);

is_deeply ( \@results_title,     ['aenean_eu_lorem'],                     'search by id' );
is_deeply ( \@results_author,    ['lorem_ipsum_dolor'],                   'search by author' );
is_deeply ( \@results_topic,     ['aenean_eu_lorem'],                     'search by topic' );
is_deeply ( \@results_complex,   ['aenean_eu_lorem'],                     'complex search' );
is_deeply ( \@results_type,      [qw(aenean_eu_lorem lorem_ipsum_dolor)], 'search by type' );
is_deeply ( \@results_not_found, [],                                      'search not found' );

is ( scalar @results_limit, 1, 'limit search' );

### SAVE ###


### DELETE ###


### CONTENT ###

done_testing;
