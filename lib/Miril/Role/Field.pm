package Miril::Role::Field;

use strict;
use warnings;

use Scalar::Util qw(blessed);
use Class::Load  qw(load_class);
use Template::Declare;
use Mouse::Role;

use Miril::TypeLib qw(FieldValidation);

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

has 'validation' => (
    is  => 'ro',
    isa => FieldValidation,
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
    default => sub { blessed(shift) . '::Data' },
);

has 'template_class' => (
    is  => 'ro',
    isa => 'Str',
    default => sub { blessed(shift) . '::Template' },
);

sub render {
    my $self = shift;
    load_class( $self->template_class );
    Template::Declare->init( dispatch_to => [$self->template_class] );
    return Template::Declare->show( $self->template_name, $self );
}

1;
