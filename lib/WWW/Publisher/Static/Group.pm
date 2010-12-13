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

has 'keys_cb' =>
(
	is       => 'ro',
	isa      => 'CodeRef',
	traits   => ['Code'],
	required => 1,
	handles  => { get_keys => 'execute' },
	
);

has 'identifier_cb' =>
(
	is       => 'ro',
	isa      => 'CodeRef',
	traits   => ['Code'],	
	required => 1,
	handles  => { get_identifier => 'execute' },
);

1;
