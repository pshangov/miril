#!perl

use strict;
use warnings;

use Test::Most;

use Miril::Group;

my $group = Miril::Group->new(
	name   => 'test',
	key_cb => sub { qw( key1 key2 ) },
);

isa_ok( $group, 'Miril::Group' );

my @keys = $group->get_keys;

is_deeply ( \@keys, [qw(key1 key2)], 'expected keys' );

done_testing;
