#!perl

use WWW::Publisher::Static::Group;

use Data::Dumper;
#use Test::More tests => 1;

my $group = WWW::Publisher::Static::Group->new(
	name          => 'test',
	identifier_cb => sub { 'test_identifier' },
	keys_cb       => sub { qw( key1 key2 ) },
);

print Dumper $group;
