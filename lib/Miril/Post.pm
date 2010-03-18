package Miril::Post;

use strict;
use warnings;

use Object::Tiny qw(
	id
	title
	body
	teaser
	path
	type
	url
	author
	published
	modified
	topics
	format
);

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}

1;
