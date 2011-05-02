#!/usr/bin/perl

use strict;
use warnings;

use Test::Most;

use Path::Class qw(file);
use File::Temp  qw(tempdir);

use Miril::Post;
use Miril::Type;
use Miril::Author;
use Miril::Topic;
use Miril::DateTime;

### PREPARE ###

my @authors = map { Miril::Author->new(
	id   => $_->[0],
	name => $_->[1],
)} [ larry => 'Larry Wall' ], [ damian => 'Damian Conway'];

my @topics = map { Miril::Topic->new(
	id   => $_->[0],
	name => $_->[1],
)} [ perl => 'Perl' ], [ python => 'Python'], [ ruby => 'Ruby' ];

my $type = Miril::Type->new(
	id       => 'news',
	name     => 'News',
	location => 'somewhere',
	template => 'some_template',
);

my %nomen = ( authors => \@authors, topics => \@topics, types => [$type] );

### PRIVATE FUNCTIONS ###

# _inflate_object_from_id

my $larry = Miril::Post::_inflate_object_from_id('larry', \@authors);
my $python_and_ruby = 
	Miril::Post::_inflate_object_from_id([qw(python ruby)], \@topics);
my @python_and_ruby = map { $_->id } @$python_and_ruby;

is($larry->id, 'larry', 'inflate single object');
is_deeply(\@python_and_ruby, [qw(python ruby)], 'inflate multiple objects');

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

my $source_file = file('t\data\aenean_eu_lorem');
my ($body, $teaser, $source, $meta) = 
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

@expected{qw(id title status type_id author_id)} = ('aenean_eu_lorem', 'Aenean Eu Lorem', 'published', 'news', 'larry');

my $base_url = 'http://www.example.com/';
my $output_path = tempdir( CLEANUP => 1 );

my $post_from_file = Miril::Post->new_from_file(\%nomen, $source_file, $output_path, $base_url);

# new_from_cache
my %cache = (
    id        => $expected{id},
    title     => $expected{title},
    #modified  => file($filename)->stat->modified,
    published => $post->published ? $post->published->epoch : undef,
    type      => $post->type->id,
    author    => $expected{author_id},
    topics    => [qw(perl)],
);

#my $post_from_cache = Miril::Post->new_from_cache(\%nomen, %cache);

my %posts_for_testing = ( 
    file => $post_from_file,
);

while ( my ( $from, $post ) = each %posts_for_testing )
{
    isa_ok( $post, 'Miril::Post' );

    is( $post->id,         $expected{id},        "id from $from"        );
    is( $post->title,      $expected{title},     "title from $from"     );
    is( $post->teaser,     $expected{teaser},    "teaser from $from"    );
    is( $post->body,       $expected{body},      "body from $from"      );
    is( $post->source,     $expected{source},    "source from $from"    );
    is( $post->status,     $expected{status},    "published from $from" );
    is( $post->type->id,   $expected{type_id},   "type from $from"      );
    is( $post->author->id, $expected{author_id}, "author from $from"    );

    is_deeply( [ map {$_->id} @{$post->topics} ],  [qw(perl)], "topics from $from" );

    #is ($post->published->, 'Funky Stuff', 'title');
    #is ($post->modified, 'TODO', 'modified');
    
    # urls and paths ...
}

done_testing;
