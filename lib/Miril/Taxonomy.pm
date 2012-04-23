package Miril::Taxonomy;

# ABSTRACT: Site metadata

use Mouse;
use List::Util qw(first);
use Ref::Explicit qw(arrayref);
use Miril::TypeLib qw(HashRefOfAuthor HashRefOfTopic HashRefOfType);

has 'types' => (
	is      => 'ro',
	isa     => HashRefOfType,
	traits  => ['Hash'],
	handles => { 
        get_type_by_id => 'get', 
        get_types      => 'values' 
    },
    coerce  => 1,
    default => sub {[]},
);

has 'fields' => (
	is      => 'ro',
	isa     => 'HashRef[Object]',
	traits  => ['Hash'],
	handles => { field => 'get', fields => 'values' },
    coerce  => 1,
    default => sub {{}},
);

sub get_topics_by_id
{
    my ($self, $ids) = @_;
    return arrayref $self->get_topic_by_id(@$ids);
}

sub get_field_named
{
	my ($self, $name) = @_;
	return first { $_->name eq $name } $self->fields;

}

1;
