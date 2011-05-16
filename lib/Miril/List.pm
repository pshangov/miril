package Miril::List;

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
	is  => 'ro',
	isa => 'HashRef',
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

has 'url' =>
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

has 'location' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'map' =>
(
	is  => 'ro',
	isa => 'Str',
	predicate => 'has_map',
);

has 'path' =>
(
	is  => 'ro',
	isa => 'Path::Class::File',
);

has 'template' =>
(
	is  => 'ro',
	isa => 'Str',
);

sub get_post_by_id
{
	my $self = shift;
	my $id = shift;

	return first { $_ eq $id } $self->get_posts;
}

1;
