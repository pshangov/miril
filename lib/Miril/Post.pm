package Miril::Post;

use strict;
use warnings;

use 

### ACCESSORS ###

use Object::Tiny qw(
	id
	title
	body
	teaser
	url
	author
	published
	modified
	topics
	type
);


### CONSTRUCTOR ###

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}

1;
