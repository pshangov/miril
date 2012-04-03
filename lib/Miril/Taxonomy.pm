package Miril::Taxonomy;

# ABSTRACT: Site metadata

use Mouse;
use Ref::Explicit qw(arrayref);
use Miril::TypeLib qw(HashRefOfAuthor HashRefOfTopic HashRefOfType);

has 'authors' => (
	is      => 'ro',
	isa     => HashRefOfAuthor,
	traits  => ['Hash'],
	handles => { 
        get_author_by_id => 'get', 
        get_authors      => 'elements', 
        has_authors      => 'count' 
    },
    coerce  => 1,
    default => sub {[]},
);

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

has 'topics' => (
	is      => 'ro',
	isa     => HashRefOfTopic,
	traits  => ['Hash'],
	handles => { 
        get_topic_by_id => 'get', 
        get_topics      => 'values', 
        has_topics      => 'count' 
    },
    coerce  => 1,
    default => sub {[]},
);

sub get_topics_by_id
{
    my ($self, $ids) = @_;
    return arrayref $self->get_topic_by_id(@$ids);
}

1;

