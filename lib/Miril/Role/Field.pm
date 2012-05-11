package Miril::Role::Field;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use Mouse::Role;

requires 'render';

requires 'process';

requires 'serialize';

has 'name' => (
    is       => 'ro', 
    isa      => 'Str',
    required => 1,
);

has 'id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'required' => (
    is  => 'ro',
    isa => 'Bool',
);

sub data_class {
    my $self = shift;
    return blessed($self) . '::Data';
}

1;
