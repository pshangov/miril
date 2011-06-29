package Miril::Config;

use strict;
use warnings;

use Path::Class qw(file dir);
use List::Util qw(first);
use Miril::Group;
use Mouse;

has 'site_dir' => 
(
	is       => 'ro',
	required => 1,
);

has 'store' => 
(
	is      => 'ro',
	default => 'File',
);

has 'filter' => (
	is      => 'ro',
	default => 'Markdown',
);

has 'template' => 
(
	is      => 'ro',
	default => 'HTML::Template',
);

has 'posts_per_page' => 
(
	is      => 'ro',
	default => 10,
);

has 'cache_path' => 
(
	is      => 'ro',
	isa     => 'Path::Class::File',
	builder => sub { file( $_[0]->site_dir, '.cache' ) },
);

has 'latest_data' => 
(
	is      => 'ro',
	isa     => 'Path::Class::File',
	builder => sub { file( $_[0]->site_dir, 'cache', 'latest.xml' ) },
);

has 'users_data' => 
(
	is      => 'ro',
	isa     => 'Path::Class::File',
	default => sub { file($_[0]->site_dir, 'users') },
);

has 'data_path' => 
(
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	default => sub { dir($_[0]->site_dir, 'posts') },
);

has 'tmpl_path' => 
(
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	builder => sub { dir($_[0]->site_dir, 'tmpl') },
);

has 'statuses' => 
(
	is      => 'ro',
	isa     => 'ArrayRef',
	default => sub { [qw(draft published)] },
);

has 'sort' => 
(
	is      => 'ro',
	default => 'published',
);

has 'topics' => 
(
	is        => 'ro',
	isa       => 'ArrayRef[Miril::Topic]',
	predicate => 'has_topics',
);

has 'types' => 
(
	is        => 'ro',
	isa       => 'ArrayRef[Miril::Type]',
	predicate => 'has_types',
);

has 'authors' => 
(
	is        => 'ro',
	isa       => 'ArrayRef',
	predicate => 'has_authors',
);

has 'lists' => 
(
	is        => 'ro',
	isa       => 'ArrayRef',
	predicate => 'has_lists',
);

has 'base_dir' => 
(
	is       => 'ro',
	required => 1,
);

has 'base_url' => 
(
	is       => 'ro',
    #required => 1,
);

has 'output_path' => 
(
	is       => 'ro',
	required => 1,
);

has 'files_path' => 
(
	is      => 'ro',
    isa     => 'Path::Class::Dir',
	default => sub { dir( $_[0]->output_path, 'files' ) },
);

has 'domain' =>
(
	is       => 'ro',
	required => 1,
);

has 'http_dir' =>
(
	is       => 'ro',
	required => 1,
);

has 'files_http_dir' =>
(
	is       => 'ro',
    isa     => 'Path::Class::Dir',
	default => sub { dir( $_[0]->http_dir, 'files' ) },
);

has 'name' =>
(
	is      => 'ro',
	default => 'Miril',
);

has 'secret' =>
(
	is      => 'ro',
	default => 'Papa was a rolling stone!',
);

has 'groups' =>
(
	is      => 'ro',
	isa     => 'ArrayRef[Miril::Group]',
	builder => '_build_groups',
);

sub _build_groups
{
	my @groups = map { Miril::Group->new(%$_) }
	{
		name          => 'topic',
		identifier_cb => sub { first {$_[0]->id eq $_->[1]} list $_[0]->topics },
		key_cb        => sub { map { $_->id } list $_[0]->topics },
	},
	{
		name          => 'type',
		identifier_cb => sub { shift->type },
		key_cb        => sub { shift->type->id },
	},
	{
		name          => 'author',
		identifier_cb => sub { shift->author },
		key_cb        => sub { shift->author },
	},
	{
		name          => 'year',
		identifier_cb => sub { shift->published },
		key_cb        => sub { shift->published->strftime('%Y') },
	},
	{
		name          => 'month',
		identifier_cb => sub { shift->published },
		key_cb        => sub { shift->published->strftime('%Y%m') },
	},
	{
		name          => 'date',
		identifier_cb => sub { shift->published },
		key_cb        => sub { shift->published->strftime('%Y%m%d') },
	};

	return \@groups;
}

1;
