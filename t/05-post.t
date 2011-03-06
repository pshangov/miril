#!/usr/bin/perl

use strict;
use warnings;

use Test::Most tests => 10;

use Miril::Post;
use Miril::Type;
use Miril::Author;
use Miril::Topic;
use Miril::DateTime;
use Path::Class;

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

=pod

my $source_file = file('t\data\aenean_eu_lorem');
my ($body, $teaser, $source, $meta) = 
	Miril::Post::_parse_source_file($source_file);

is( $body, <<EoBody, 'xhtml body from file' );

EoBody

is( $teaser, <<EoTeaser, 'xhtml teaser from file' );

EoTeaser

is( $source, <<EoSource, 'source from file' );
Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.
EoSource

is( $meta, <<EoMeta, 'meta from file' );
Title: Aenean Eu Lorem
Author: larry
Type: news
Published: 2010-05-26 18:22
Topics: perl
EoMeta

=cut

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
