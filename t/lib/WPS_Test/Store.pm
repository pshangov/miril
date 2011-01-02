package WPS_Test::Store;

use strict;
use warnings;

use Any::Moose;
use List::Util qw(first reduce);
use Syntax::Keyword::Gather qw(gather take);
use WPS_Test::Post;

with 'WWW::Publisher::Static::Store';

sub all 
{
	return map
	{
		WPS_Test::Post->new(
			id    => $_->{id},
			title => $_->{title},
			type  => $_->{type},
		);
	}
	(
		{ 
			id    => 'post1',
			title => 'Title One',
			type  => 'type1',
		},
		{ 
			id    => 'post2',
			title => 'Title Two',
			type  => 'type1',
		},
		{ 
			id    => 'post3',
			title => 'Title Three',
			type  => 'type2',
		},
	);
}

sub search
{
	my ($self, $condition) = @_;
	my @keys = keys %$condition;

	return gather {
		foreach my $post ($self->all)
		{
			take ($post) if 
				reduce { $a && $b }  
				map { $post->$_ eq $condition->{$_} } @keys;
		}
	};
}

sub get_post_by_id
{
	return first { $_->id eq shift } $_[0]->all;
}

1;
