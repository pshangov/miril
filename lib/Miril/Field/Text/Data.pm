package Miril::Field::Text::Data;

use strict;
use warnings;

use Mouse;

has 'value' => 
(
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

1;
