#!/usr/bin/perl

use strict;
use warnings;

use Test::Most;

use Path::Class qw(file);
use File::Temp  qw(tempdir);
use Miril::Field::Option;
use Miril::Post;
use Miril::Type;
use Miril::DateTime;
use Miril::Taxonomy;

### PREPARE ###

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
	name     => 'author',
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
	location => 'news/%(id)s.html',
	template => 'template',
);

my $taxonomy = Miril::Taxonomy->new( 
    types  => { news => $type }, 
	fields => { author => $authors, topic => $topics },
);

### PRIVATE FUNCTIONS ###

# _parse_meta

my %meta = Miril::Post::_parse_meta(<<EoMeta);
Title: Funky Stuff
Author: damian
Topics: perl python
EoMeta

is( $meta{title}, 'Funky Stuff', 'meta title' );
is( $meta{author}, 'damian', 'meta author' );
is_deeply( $meta{topics}, [qw(perl python)], 'meta topics' );

# _parse_source_file

my $source_file = file(qw(t data aenean_eu_lorem));
my ($source, $body, $teaser, $meta) = 
	Miril::Post::_parse_source_file($source_file);

my %expected;

$expected{body} = <<EoBody;
<p>Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.</p>
EoBody

$expected{teaser} = <<EoTeaser;
<p>Aenean eu lorem at odio placerat fringilla.</p>
EoTeaser

$expected{source} = <<EoSource;
Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.
EoSource

$expected{meta} = <<EoMeta;
Title: Aenean Eu Lorem
Author: larry
Type: news
Published: 2010-05-26 18:22
Topics: perl
EoMeta

chomp $expected{meta};

eq_or_diff( $body,   $expected{body},   'xhtml body from file' );
eq_or_diff( $teaser, $expected{teaser}, 'xhtml teaser from file' );
eq_or_diff( $source, $expected{source}, 'source from file' );
eq_or_diff( $meta,   $expected{meta},   'meta from file' );

# _parse_source

my ($body_from_source, $teaser_from_source) = Miril::Post::_parse_source($expected{source});

eq_or_diff( $body_from_source,   $expected{body},   'xhtml body from source' );
eq_or_diff( $teaser_from_source, $expected{teaser}, 'xhtml teaser from source' );

### CONSTRUCTORS ###

# new

my $modified = Miril::DateTime->now;

my %attributes = (
	id       => 'test_id',
	title    => 'Test Title',
	status   => 'draft',
);

my $post = Miril::Post->new(
	%attributes,
	type     => $type,
	modified => $modified,

);

isa_ok($post, 'Miril::Post');

foreach my $attribute ( keys %attributes )
{
	is( $post->$attribute, $attributes{$attribute}, $attribute );
}

is($post->type->id, 'news', 'type');

# new_from_file

@expected{qw(id title status type_id author_id published_ymdhm)} 
    = ('aenean_eu_lorem', 'Aenean Eu Lorem', 'published', 'news', 'larry', '2010-05-26 18:22');

my $post_from_file = Miril::Post->new_from_file($source_file, $taxonomy);

# new_from_cache

my $modified_epoch = $source_file->stat->mtime;

my %cache = (
    id          => $expected{id},
    title       => $expected{title},
    modified    => Miril::DateTime->from_epoch($modified_epoch),
    published   => Miril::DateTime->from_ymdhm($expected{published_ymdhm}),
    type        => $type,
    author      => $authors->option('larry'),
    topics      => [$topics->option('perl')],
    source_path => $source_file,

);

my $post_from_cache = Miril::Post->new_from_cache(\%cache);

# new_from_params

my %params = (
    id        => $expected{id},
    title     => $expected{title},
    author    => $expected{author_id},
    topics    => [qw(perl)],
    type      => $expected{type_id},
    source    => $expected{source},
    status    => 'published',
    published => $expected{published_ymdhm},
);

my $post_from_params = Miril::Post->new_from_params(\%params, $taxonomy );

my %posts_for_testing = 
(
    file   => $post_from_file,
    cache  => $post_from_cache,
    params => $post_from_params,
);

while ( my ( $from, $post ) = each %posts_for_testing )
{
    isa_ok( $post, 'Miril::Post' );

    is( $post->id,         $expected{id},        'id'     . " from $from" );
    is( $post->title,      $expected{title},     'title'  . " from $from" );
    is( $post->teaser,     $expected{teaser},    'teaser' . " from $from" );
    is( $post->body,       $expected{body},      'body'   . " from $from" );
    is( $post->source,     $expected{source},    'source' . " from $from" );
    is( $post->status,     $expected{status},    'status' . " from $from" );
    is( $post->type->id,   $expected{type_id},   'type'   . " from $from" );
    is( $post->author->id, $expected{author_id}, 'author' . " from $from" );

    is_deeply( [ map {$_->id} @{$post->topics} ],  [qw(perl)], "topics from $from" );
    is ($post->published->as_ymdhm, $expected{published_ymdhm}, "published from $from");

    # source_path and modified do not exist yet for newly-created posts from params
    if ( $from ne 'params')
    {
        is ( $post->modified->as_epoch, $modified_epoch, "modified from $from");
        is ( $post->source_path->stringify, $source_file, "source_path from $from" );
    }

    # path, url and tag_url are only used during publishing and 
    # therefore are supplied only to objects created with new_from_file
    if ( $from eq 'file')
    {
        my $expected_path     = file('news/aenean_eu_lorem.html');
        my $expected_url      = 'news/aenean_eu_lorem.html';

        is ( $post->path,    $expected_path,    "path from $from"    );
        is ( $post->url,     $expected_url,     "url from $from"     );
    }
}

done_testing;
