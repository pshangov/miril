package Miril::Role::Field;

use strict;
use warnings;

use Scalar::Util qw(blessed);
use Class::Load  qw(load_class);

use Mouse::Role;

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

has 'template_name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => 'default',
);

has 'data_class' => (
    is  => 'ro',
    isa => 'Str',
    default => sub { blessed($self) . '::Data' },
);

has 'template_class' => (
    is  => 'ro',
    isa => 'Str',
    default => sub { blessed($self) . '::Template' },
);

sub render {
    my $self = shift;
    load_class( $self->template_class );
    return $self->template_class->show($self->template_name);
}

1;
