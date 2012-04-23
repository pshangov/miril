package Miril::Field::Option;

use strict;
use warnings;

use Mouse;

with 'Miril::Role::Field';

has 'multiple' => ( is => 'ro', isa => 'Bool' );

#TODO
has '+group_callback' => ( default => sub { return sub {
    $_[0]->author->id, { author => $_[0]->author->id, object => $_[0]->author } 
} } );

has 'options' => 
(
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
    traits   => ['Hash'],
    handles  => { has_option => 'exists', get_option => 'get' }
);

sub process {
    my ( $self, $string ) = @_;
    
    my @text_ids = grep { $self->has_option($_) } split /\s+/, $string;

    return map { $self->data_class->new(
        name  => $_,
        value => $self->get_option($_),
    ) } @text_ids;
}

sub render { 1 }

1;
