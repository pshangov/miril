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

has '_formatter' => 
(
    is      => 'ro',
    isa     => 'Text::Sprintf::Named',
    default => sub { Text::Sprintf::Named->new( {fmt => $_[0]->location}) },
);

sub path
{
    my ( $self, $id ) = @_;
    return file( $self->_formatter->format( {args => { id => $id } }) );
}

1;
