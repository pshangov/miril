package Miril::Role::Field;

use strict;
use warnings;

use Mouse::Role;

requires 'render';

requires 'process';

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

has 'types' => (
    is        => 'ro',
    isa       => 'ArrayRef[Str]',
    predicate => 'has_defined_types',
);

has 'group_callback' => 
(
    is        => 'ro',
    isa       => 'CodeRef',
    predicate => 'can_group',
);

sub data_class {
    return __PACKAGE__ . '::Data';
}

1;
