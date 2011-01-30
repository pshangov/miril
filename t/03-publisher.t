#!perl
use strict;
use warnings;

use rlib;
use Test::Most;
use Path::Class;
use Data::Dumper::Concise qw(Dumper);
use List::MoreUtils qw(true);
use File::Temp qw(tempdir);
use WWW::Publisher::Static::List;
use WWW::Publisher::Static::Group;
use WWW::Publisher::Static::Publisher;
use WPS_Test::Post;
use WPS_Test::Template;

### SETUP ###

my $dir = dir( tempdir(CLEANUP => 1) );
#my $dir = dir( tempdir() );

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

my %list_options = (
	id       => 'list1',
	title    => 'List One',
	template => 'list_template',
	posts    => \@posts,
);

my $ordinary_list = WWW::Publisher::Static::List->new(
	%list_options,
	location => 'list.html',
);

my $paged_list = WWW::Publisher::Static::List->new(
	%list_options,
	page     => 2,
	location => 'page/%(page)d/index.html',
);

my $grouped_list = WWW::Publisher::Static::List->new(
	%list_options,
	group    => 'type',
	location => 'type/%(type)s.html',
	map      => 'list1_map.html',
);

my $paged_and_grouped_list = WWW::Publisher::Static::List->new(
	%list_options,
	group    => 'type',
	page     => 1,
	location => 'type/%(type)s/%(page)d/index.html',
);

my $group = WWW::Publisher::Static::Group->new(
	name        => 'type',
	key_cb      => sub { $_[0]->type, { type => $_[0]->type } },
);

my %publisher_options = (
	posts       => \@posts,
	template    => WPS_Test::Template->new,
	output_path => $dir,
	stash       => undef,
	rebuild     => 1,
);

my $publisher_ordinary_list = WWW::Publisher::Static::Publisher->new(
	%publisher_options,
	lists => [$ordinary_list],
);

my $publisher_paged_list = WWW::Publisher::Static::Publisher->new(
	%publisher_options,
	lists => [$paged_list],
);

my $publisher_grouped_list = WWW::Publisher::Static::Publisher->new(
	%publisher_options,
	lists  => [$grouped_list],
	groups => [$group],
);

my $publisher_paged_and_grouped_list = WWW::Publisher::Static::Publisher->new(
	%publisher_options,
	lists  => [$paged_and_grouped_list],
	groups => [$group],
);

###############
### TESTING ###
###############

isa_ok($publisher_ordinary_list, 'WWW::Publisher::Static::Publisher', "publisher class");

# POSTS #

my @test_posts = $publisher_ordinary_list->prepare_posts;
ok( List::MoreUtils::all( sub {$_->isa('WWW::Publisher::Static::Post')}, @test_posts ), "post class" );

my @post_ids = map {$_->id} @test_posts;
is_deeply( \@post_ids, [qw(post1 post2 post3)], "post objects work" );

my @post_paths = map {$_->path} @test_posts;
my @expected_post_paths = map { file $_  } 'data/post1.html', 'data/post2.html', 'data/post3.html';
is_deeply( \@post_paths, \@expected_post_paths, "post paths");

# SIMPLE LIST #

my @test_ordinary_lists = $publisher_ordinary_list->prepare_lists;
isa_ok( $test_ordinary_lists[0], 'WWW::Publisher::Static::List', "list class" );

is_deeply( [map {$_->path} @test_ordinary_lists], ['list.html'], "ordinary list path");

# PAGING #

my @test_paged_lists = $publisher_paged_list->prepare_lists;
is( scalar @test_paged_lists, 2, "number of paged lists" );

my @paged_paths = map {$_->path} @test_paged_lists;
my @expected_paged_paths = map { file $_  } 'page/1/index.html', 'page/2/index.html';
is_deeply( \@paged_paths, \@expected_paged_paths, "paged paths");

# GROUPING #

my @test_grouped_lists = $publisher_grouped_list->prepare_lists;
my @map_pages = grep { $_->path eq "list1_map.html" } @test_grouped_lists;
my @group_pages = grep { $_->path ne "list1_map.html" } @test_grouped_lists;
my @grouped_paths = map {$_->path} @group_pages;
my @expected_grouped_paths = map { file $_  } 'type/type1.html', 'type/type2.html';

is( scalar @map_pages, 1, "map page");
is( scalar @group_pages, 2, "number of grouped pages");
is_deeply( \@grouped_paths, \@expected_grouped_paths, "grouped paths");

# PAGING AND GROUPING #

my @test_grouped_and_paged_lists = $publisher_paged_and_grouped_list->prepare_lists;
my @grouped_and_paged_paths = map {$_->path} @test_grouped_and_paged_lists;
my @expected_grouped_and_paged_paths = map { file $_ } 
	'type/type1/1/index.html',
	'type/type1/2/index.html',
	'type/type2/1/index.html';

is( scalar @test_grouped_and_paged_lists, 3, "number of grouped and paged pages");
is_deeply( \@grouped_and_paged_paths, \@expected_grouped_and_paged_paths, "paged and grouped paths");

#$publisher_ordinary_list->publish;
#exec("start " . $dir->stringify);

done_testing();


