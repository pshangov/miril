package Miril::List;

# ABSTRACT: Post collection object

use strict;
use warnings;

use Carp qw(croak);
use List::Util qw(first);
use Miril::DateTime;

use Mouse;

has 'posts' => 
(
	is      => 'ro',
	isa     => 'ArrayRef[Miril::Post]',
	traits  => ['Array'],
	handles => { 
        count     => 'count',
        get_posts => 'elements',
    },
);

has 'key' =>
(
	is            => 'ro',
	isa           => 'HashRef',
    documentation => 'Set from taxonomy by Miril::Publisher',
);

has 'title' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'id' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'group' =>
(
	is        => 'ro',
	isa       => 'Str',
	predicate => 'is_grouped',
);

has 'timestamp' =>
(
	is      => 'ro',
	isa     => 'Miril::DateTime',
	default => sub { Miril::DateTime->now },
);

has 'page' =>
(
	is        => 'ro',
	isa       => 'Int',
	predicate => 'is_paged',
);

has 'path' =>
(
	is            => 'ro',
	isa           => 'Path::Class::File',
    documentation => 'Caclulated from $self->location by Miril::Publisher',
);

has 'template' =>
(
	is       => 'ro',
	isa      => 'Str',
    required => 1,
);

sub group_key
{
    my $self = shift;
    return $self->key->{object} if $self->is_grouped;
}

sub get_post_by_id
{
	my $self = shift;
	my $id = shift;

	return first { $_ eq $id } $self->get_posts;
}

with 'Miril::Role::URL';

1;
