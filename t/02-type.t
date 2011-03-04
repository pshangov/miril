#!/usr/bin/perl

use strict;
use warnings;

use Test::Most tests => 5;

use Miril::Type;

my %attributes = (
	id       => 'my_type',
	name     => 'My Type',
	location => 'somewhere',
	template => 'some_template',
);

my $type = Miril::Type->new(%attributes);

isa_ok($type, 'Miril::Type');

foreach my $attribute ( keys %attributes )
{
	is( $type->$attribute, $attributes{$attribute}, $attribute );
}
