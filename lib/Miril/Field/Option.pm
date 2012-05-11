package Miril::Field::Option;

use strict;
use warnings;

use Class::Load qw(load_class);
use Ref::Explicit qw(arrayref);

use Mouse;

with 'Miril::Role::Field';
with 'Miril::Role::Group';

has 'multiple' => ( is => 'ro', isa => 'Bool' );

has 'options' => 
(
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
    traits   => ['Hash'],
    handles  => { has_option => 'exists', option => 'get' }
);

sub group_callback
{ 
    return sub {
        $_[0]->author->id, { author => $_[0]->author->id, object => $_[0]->author }
    };
}

sub process
{
    my ( $self, $string ) = @_;
    
    my @text_ids = ref $string
        ? @$string # handle arrayref of multivalue CGI.pm params
        : grep { $self->has_option($_) } split /\s+/, $string;
    
    my $data_class = $self->data_class;
    load_class $data_class;

    my @options = map { $self->data_class->new(
        name  => $_,
        value => $self->option($_),
    ) } @text_ids;

    return $self->multiple ? \@options : $options[0];
}

sub serialize
{
	my ( $self, $data ) = @_;

	if ($data)
	{
		return $self->multiple 
			? join ' ', map { $_->name } @$data 
			: $data->name;
	}
	else
	{
		return '';
	}
}

sub render { 1 }

1;
