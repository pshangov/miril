package Miril::Taxonomy;

use Mouse;
use Ref::Explicit qw(arrayref);

has 'authors' => (
	is      => 'ro',
	isa     => 'HashRef[Miril::Author]',
	traits  => ['Hash'],
	handles => { get_author_by_id => 'get' },
);

has 'types' => (
	is      => 'ro',
	isa     => 'HashRef[Miril::Type]',
	traits  => ['Hash'],
	handles => { get_type_by_id => 'get' },
);

has 'topics' => (
	is      => 'ro',
	isa     => 'HashRef[Miril::Topic]',
	traits  => ['Hash'],
	handles => { get_topic_by_id => 'get' },
);

sub get_topics_by_id
{
    my ($self, @ids) = @_;
    return arrayref $self->get_topic_by_id(@ids);
}

1;

