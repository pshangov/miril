use strict;
use warnings;

use Test::Most;
use Miril::List;
use Miril::Post;
use Miril::Type;

my $type1 = Miril::Type->new( 
    id       => 'type1', 
    name     => 'Type I',  
    location => 'type1', 
    template => 'type1.tmpl'
);

my $type2 = Miril::Type->new( 
    id       => 'type2', 
    name     => 'Type II', 
    location => 'type2', 
    template => 'type2.tmpl'
);

my @posts = map
{
	Miril::Post->new(
		id    => $_->{id},
		title => $_->{title},
		type  => $_->{type},
	);
}
(
	{ 
		id    => 'post1',
		title => 'Title One',
		type  => $type1,
	},
	{ 
		id    => 'post2',
		title => 'Title Two',
		type  => $type2,
	},
	{ 
		id    => 'post3',
		title => 'Title Three',
		type  => $type2,
	},
);

my $list = Miril::List->new(
    id       => 'list1',
	title    => 'List One',
	template => 'list_template',
	posts    => \@posts,
	group    => 'type',
	page     => 1,
	location => 'type/%(type)s/%(page)d/index.html',
);

isa_ok( $list, 'Miril::List' );

done_testing;
