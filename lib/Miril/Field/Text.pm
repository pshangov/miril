package Miril::Field::Text;

use strict;
use warnings;

use Miril::Field::Text::Data;

use Mouse;

with 'Miril::Role::Field';


sub process 
{
    my ( $self, $string ) = @_;
    return $self->data_class->new( value => $string );
}

sub serialize
{
	my ($self, $data) = @_;
	return $data ? '' : $data->value;
}

sub render { 1 }

1;
