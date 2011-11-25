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
	default => sub { {} },
    traits  => [qw(Hash)],
    handles => { template_options => 'elements' },
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
    traits  => ['Array'],
    handles => { get_statuses => 'elements' },
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
    default   => sub { [] },
    traits    => ['Array'],
    handles   => { get_topics => 'elements' },
);

has 'types' => 
(
	is        => 'ro',
	isa       => 'ArrayRef[Miril::Type]',
	predicate => 'has_types',
    default   => sub { [] },
    traits    => ['Array'],
    handles   => { get_types => 'elements' },
);

has 'authors' => 
(
	is        => 'ro',
	isa       => 'ArrayRef',
	predicate => 'has_authors',
    default   => sub { [] },
    traits    => ['Array'],
    handles   => { get_authors => 'elements' },
);

has 'lists' => 
(
	is        => 'ro',
	isa       => 'ArrayRef[Miril::List::Spec]',
	predicate => 'has_lists',
    traits    => ['Array'],
    handles   => { get_lists => 'elements' },
);

has 'output_path' => 
(
	is       => 'ro',
	required => 1,
);

has 'files' => 
(
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub{ { path => 'files', url => '/files/' } },
);

has 'files_path' => 
(
	is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
	default => sub { dir( $_[0]->files->{path} ) },
);

has 'files_url' => 
(
	is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
	default => sub { $_[0]->files->{url} },
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

has 'stash' =>
(
    is  => 'ro',
    isa => 'HashRef',
);

has 'groups' =>
(
	is      => 'ro',
	isa     => 'ArrayRef[Miril::Group]',
	builder => '_build_groups',
);

has 'sync' => 
(
	is  => 'ro',
    isa => 'Str',
);

sub _build_groups
{
	my @groups = map { Miril::Group->new(%$_) }
	{
		name   => 'topic',
		key_cb => sub { 
            map { $_->id => { topic => $_->id, object => $_ } } 
                $_[0]->get_topics
        },
	},
	{
		name   => 'type',
		key_cb => sub { 
            $_[0]->type->id => { type => $_[0]->type->id, object => $_[0]->type } 
        },
	},
	{
		name   => 'author',
		key_cb => sub { 
            $_[0]->author->id, { author => $_[0]->author->id, object => $_[0]->author } 
        },
	},
	{
		name   => 'year',
		key_cb => sub { 
            $_[0]->published->as_strftime('%Y') => { 
                year   => $_[0]->published->as_strftime('%Y'),
                object => $_[0]->published,
            } 
        },
	},
	{
		name   => 'month',
		key_cb => sub { 
            $_[0]->published->as_strftime('%Y%m') => { 
                year   => $_[0]->published->as_strftime('%Y'),
                month  => $_[0]->published->as_strftime('%m'),
                object => $_[0]->published,
            }  
        },
	},
	{
		name      => 'date',
		key_cb    => sub { 
            $_[0]->published->as_strftime('%Y%m%d') => { 
                year   => $_[0]->published->as_strftime('%Y'),
                month  => $_[0]->published->as_strftime('%m'),
                date   => $_[0]->published->as_strftime('%d'),
                object => $_[0]->published,
            }              
        },
	};

	return \@groups;
}

1;
