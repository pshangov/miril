#!perl
use strict;
use warnings;

use Test::Most;
use WWW::Publisher::Static::List;
use WWW::Publisher::Static::Group;
use WWW::Publisher::Static::Publisher;
use Path::Class;
use FindBin;
use lib "$FindBin::Bin/lib";
use WPS_Test::Post;
use WPS_Test::Template;

my @posts = map
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

my @list_definitions = map 
{
	WWW::Publisher::Static::List->new(
		id       => $_->{id},
		title    => $_->{title},
		template => $_->{template},
		location => $_->{location},
		match    => $_->{match},
		posts    => $_->{posts},
		page     => $_->{page},
		#map      => $_->{map},
		#group    => $_->{group},
	);
}
(
	{
		id       => 'list1',
		title    => 'List One',
		template => 'list_template',
		location => 'list1.html',
		map      => 'list1_map.html',
		posts    => \@posts,
		page     => 2,
	},
);

my @groups = WWW::Publisher::Static::Group->new(
	name        => 'topic',
	sort_key_cb => sub { shift->topic },
	key_cb      => sub { { topic => shift->topic } },
);

my $publisher = WWW::Publisher::Static::Publisher->new(
	posts       => \@posts,
	lists       => \@list_definitions,
	groups      => \@groups,
	template    => WPS_Test::Template->new,
	output_path => dir('.'),
	stash       => undef,
	rebuild     => 1,
);

isa_ok($publisher, 'WWW::Publisher::Static::Publisher', "publisher class");

my @test_posts = $publisher->prepare_posts;
isa_ok( $test_posts[0], 'WWW::Publisher::Static::Post', "post class" );

my @post_ids = map {$_->id} @test_posts;
is_deeply( \@post_ids, [qw(post1 post2 post3)], "post objects work" );

my @test_lists = $publisher->prepare_lists;
isa_ok( $test_lists[0], 'WWW::Publisher::Static::List', "list class" );
is( scalar @test_lists, 2, "number of pages" );

done_testing();
