package Miril::Type;

# ABSTRACT: Type object

use strict;
use warnings;

use Mouse;
use Text::Sprintf::Named;
use Path::Class qw(file);
use Miril::TypeLib qw(TextId Str);

has 'id' =>
(
	is       => 'ro',
	isa      => TextId,
	required => 1,
);

has 'name' =>
(
	is       => 'ro',
	isa      => Str,
	required => 1,
);

has 'location' =>
(
	is => 'ro',
	isa      => Str,
	required => 1,
);

has 'template' =>
(
	is       => 'ro',
	isa      => Str,
	required => 1,
);

has 'fields' =>
(
    is        => 'ro',
    isa       => 'ArrayRef',
    default   => sub { [] },
    traits    => ['Array'],
    handles   => { field_list => 'elements', first_field => 'first' },
);

has '_formatter' => 
(
    is      => 'ro',
    isa     => 'Text::Sprintf::Named',
    default => sub { Text::Sprintf::Named->new( {fmt => $_[0]->location}) },
);

sub has_field
{
    my ( $self, $name ) = @_;
    return 1 if $self->first_field( sub { $_ eq $name } );
}

sub path
{
    my ( $self, $id ) = @_;
    return file( $self->_formatter->format( {args => { id => $id } }) );
}

1;
