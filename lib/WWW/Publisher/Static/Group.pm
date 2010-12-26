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

has 'key_cb' =>
(
	is       => 'ro',
	isa      => 'CodeRef',
	traits   => ['Code'],
	required => 1,
	handles  => { get_keys => 'execute' },
	
);

has 'key_as_object_cb' =>
(
	is       => 'ro',
	isa      => 'CodeRef',
	traits   => ['Code'],	
	required => 1,
	handles  => { get_key_as_object => 'execute' },
);

has 'key_as_hash_cb' =>
(
	is       => 'ro',
	isa      => 'CodeRef',
	traits   => ['Code'],	
	required => 1,
	handles  => { get_key_as_hash => 'execute' },
);

1;
