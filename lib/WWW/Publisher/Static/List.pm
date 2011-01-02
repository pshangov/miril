package WWW::Publisher::Static::List;

use strict;
use warnings;
use autodie;

use Carp qw(croak);
use Ref::List qw(list);
use List::Util qw(first);
use Miril::DateTime;

use Mouse;

has 'posts' => 
(
	is      => 'ro',
	isa     => 'ArrayRef[WWW::Publisher::Static::Post]',
	traits  => ['Array'],
	handles => { count => 'count' },
);

has 'key' =>
(
	is  => 'ro',
	isa => 'Str',
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
	default => sub { Miril::DateTime->new(time()) },
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

sub get_post_by_id
{
	my $self = shift;
	my $id = shift;

	return first { $_ eq $id } list $self->posts;
}





1;
