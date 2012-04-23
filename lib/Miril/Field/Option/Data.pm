package Miril::Field::Option::Data;

use strict;
use warnings;

use Mouse;

has 'name' => 
(
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'value' => 
(
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

1;
