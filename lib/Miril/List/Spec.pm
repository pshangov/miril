package Miril::List::Spec;

# ABSTRACT: List specification object

use strict;
use warnings;

use Mouse;

use Carp qw(croak);
use Ref::List qw(list);
use List::Util qw(first);
use Miril::DateTime;

has 'name' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'id' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'location' =>
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

has 'page' =>
(
	is        => 'ro',
	isa       => 'Int',
	predicate => 'is_paged',
);

has 'template' =>
(
	is  => 'ro',
	isa => 'Str',
);

has 'match' =>
(
    is      => 'ro',
    isa     => 'HashRef',
    traits  => ['Hash'],
    handles => { search_options => 'elements' },
);

has 'map' =>
(
	is        => 'ro',
	isa       => 'HashRef',
	predicate => 'has_map',
    traits    => ['Hash'],
    handles   => 
    {
        map_name     => [ get => 'name'     ],
        map_template => [ get => 'template' ],
        map_location => [ get => 'location' ],
    }
    
);

has 'posts' => 
(
	is  => 'rw',
	isa => 'ArrayRef[Miril::Post]',
);

1;
