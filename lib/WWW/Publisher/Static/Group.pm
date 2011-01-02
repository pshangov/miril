package WWW::Publisher::Static::Group;

use strict;
use warnings;

use Any::Moose;

has 'name' => 
(
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has 'sort_key_cb' =>
(
	is       => 'ro',
	isa      => 'CodeRef',
	traits   => ['Code'],
	required => 1,
	handles  => { get_sort_keys => 'execute' },
	
);

has 'key_cb' =>
(
	is       => 'ro',
	isa      => 'CodeRef',
	traits   => ['Code'],	
	required => 1,
	handles  => { get_key => 'execute' },
);

1;
