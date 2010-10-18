package Miril::Config;

use strict;
use warnings;

use File::Spec ();

use Mouse;

has 'miril_dir' => 
(
	is       => 'ro',
	required => 1,
);

has 'site' => 
(
	is       => 'ro',
	required => 1,
);

has 'site_dir' => 
(
	is      => 'ro',
	builder => sub 
	{ 
		my $self = shift;
		File::Spec->catdir($self->miril_dir, 'sites', $self->site); 
	},
);

has 'store' => 
(
	is      => 'ro',
	default => 'File',
);

has 'user_manager' => 
(
	is      => 'ro',
	default => 'XMLTPP',
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

has 'cache_data' => 
(
	is      => 'ro',
	builder => sub 
	{ 
		my $self = shift;
		File::Spec->catfile($self->site_dir, 'cache', 'cache.xml'); 
	},
);

has 'latest_data' => 
(
	is      => 'ro',
	builder => sub 
	{ 
		my $self = shift;
		File::Spec->catfile($self->site_dir, 'cache', 'latest.xml'); 
	},
);

has 'users_data' => 
(
	is      => 'ro',
	builder => sub 
	{ 
		my $self = shift;
		File::Spec->catfile($self->site_dir, 'cfg', 'users.xml');
	},
);

has 'data_path' => 
(
	is      => 'ro',
	builder => sub 
	{ 
		my $self = shift;
		File::Spec->catdir($self->site_dir, 'data');
	},
);

has 'tmpl_path' => 
(
	is      => 'ro',
	builder => sub 
	{ 
		my $self = shift;
		File::Spec->catdir($self->site_dir, 'tmpl');
	},
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

has 'output_path' => 
(
	is       => 'ro',
	required => 1,
);

has 'files_path' => 
(
	is      => 'ro',
	default => sub { File::Spec->catdir( my $_[0]->output_path, 'files' ) },
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
	default => sub { File::Spec->catdir( my $_[0]->http_dir, 'files' ) },
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

1;
