#!/usr/bin/perl

use strict;
use warnings;

use Test::Most tests => 1;

use Miril::Post;
use Miril::Type;
use Miril::DateTime;

my $type = Miril::Type->new(
	id       => 'my_type',
	name     => 'My Type',
	location => 'somewhere',
	template => 'some_template',
);

my $modified = Miril::DateTime->now;

my $post = Miril::Post->new(
	id       => 'test_id',
	title    => 'Test Title',
	status   => 'draft',
	type     => $type,
	modified => $modified,
);

isa_ok($post, 'Miril::Post');
