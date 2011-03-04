#!/usr/bin/perl

use strict;
use warnings;

use Test::Most tests => 3;

use Miril::Author;

my %attributes = (
	id       => 'author_id',
	name     => 'Author Name',
);

my $type = Miril::Author->new(%attributes);

isa_ok($type, 'Miril::Author');

foreach my $attribute ( keys %attributes )
{
	is( $type->$attribute, $attributes{$attribute}, $attribute );
}


