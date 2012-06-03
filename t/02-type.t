#!/usr/bin/perl

use strict;
use warnings;

use Test::Most tests => 8;
use Path::Class qw(file);
use Miril::Type;

my %attributes = (
	id       => 'my_type',
	name     => 'My Type',
	location => 'somewhere/%(id)s.html',
	template => 'some_template',
);

my $type = Miril::Type->new(%attributes);

isa_ok($type, 'Miril::Type');

foreach my $attribute ( keys %attributes )
{
	is( $type->$attribute, $attributes{$attribute}, $attribute );
}

my $formatter = $type->_formatter;
isa_ok($formatter, 'Text::Sprintf::Named');

my $path = $type->path('over_the_rainbow');
isa_ok ($path, 'Path::Class::File');
is ( $path, file('somewhere/over_the_rainbow.html'), 'formatted path');
