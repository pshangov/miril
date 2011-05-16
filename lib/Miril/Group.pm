package Miril::Group;

use strict;
use warnings;

use Mouse;

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

no Mouse;

1;

