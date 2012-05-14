package Miril::Taxonomy;

# ABSTRACT: Site metadata

use Mouse;
use List::Util     qw(first);
use Miril::TypeLib qw(HashRefOfType);

has 'types' => (
	is      => 'ro',
	isa     => HashRefOfType,
	traits  => ['Hash'],
	handles => { type => 'get', get_types => 'values' },
    coerce  => 1,
    default => sub {[]},
);

has 'fields' => (
	is      => 'ro',
	isa     => 'HashRef[Object]',
	traits  => ['Hash'],
	handles => {
        field       => 'get',
        field_names => 'keys',
        get_fields  => 'values',
        has_field   => 'exists',
    },
    coerce  => 1,
    default => sub {{}},
);

sub get_field_named
{
	my ($self, $name) = @_;
	return first { $_->name eq $name } $self->get_fields;

}

1;
