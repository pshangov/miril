#!/usr/bin/perl

use strict;
use warnings;

use Test::Most tests => 15;

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

eq_or_diff( $body, <<EoBody, 'xhtml body from file' );
<p>Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.</p>
EoBody

eq_or_diff( $teaser, <<EoTeaser, 'xhtml teaser from file' );
<p>Aenean eu lorem at odio placerat fringilla.</p>
EoTeaser

eq_or_diff( $source, <<EoSource, 'source from file' );
Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.
EoSource

my $expected_meta = <<EoMeta;
Title: Aenean Eu Lorem
Author: larry
Type: news
Published: 2010-05-26 18:22
Topics: perl
EoMeta

chomp $expected_meta;

eq_or_diff( $meta, $expected_meta, 'meta from file' );

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

my $base_url = 'http://www.example.com/';
my $output_path = tempdir( CLEANUP => 1 );

my $post_from_file = Miril::Post->new_from_file(\%nomen, $source_file, $output_path, $base_url);

isa_ok($post_from_file, 'Miril::Post');
