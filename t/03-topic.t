#!/usr/bin/perl

use strict;
use warnings;

use Test::Most tests => 3;

use Miril::Topic;

my %attributes = (
	id       => 'my_topic',
	name     => 'My Topic',
);

my $type = Miril::Topic->new(%attributes);

isa_ok($type, 'Miril::Topic');

foreach my $attribute ( keys %attributes )
{
	is( $type->$attribute, $attributes{$attribute}, $attribute );
}

