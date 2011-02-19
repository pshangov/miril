package Miril::Post;

use strict;
use warnings;
use Any::Moose;
use Path::Class;

### ID ###

has 'id' => 
(
	is            => 'ro',
	isa           => 'Str',
	required      => 1,
	documentation => 'Unique text ID of the post',
);

### CONTENT ###

has 'title' => 
(
	qw(:ro :required),
	isa           => 'Str',
	documentation => 'Post title',
);

has 'source' => 
(
	qw(:rw :lazy),
	isa           => 'Str',
	builder       => '_build_source',
	documentation => 'Post body in the original markup format (e.g. Markdown, Textile)',
);

has 'body' =>
(
	qw(:rw :lazy),
	isa           => 'Str',
	builder       => '_build_body',
	documentation => 'Post body in processed HTML',
);

has 'teaser' =>
(
	qw(:rw :lazy),
	isa           => 'Str',
	builder       => '_build_teaser',
	documentation => 'Post teaser in processed HTML',
);

### METADATA ###

has 'author' => 
(
	qw(:ro),
	isa           => 'Str',
	documentation => 'Post author',
);

has 'topics' => 
(
	qw(:ro :weak_ref),
	isa           => 'ArrayRef[Miril::Topic]',
	documentation => 'List of Miril::Topic objects for this post',
);

has 'type' => 
(
	qw(:ro :required :weak_ref),
	isa           => 'Miril::Type',
	handles       => { template => 'template' },
	documentation => 'Type of the post',
);

has 'status' =>
(
	qw(:rw :required),
	isa           => 'Str',
	builder       => '_build_status'
	documentation => 'Post status: draft or published',
);

has 'published' => 
(
	qw(:ro),
	trigger       => sub { $_[0]->status('published') },
	documentation => 'Time when the post was published',
);

has 'modified' => 
(
	qw(:ro :lazy :required),
	builder       => '_build_modified',
	documentation => 'Time when the post source post was last modified',
);

### PATHS AND URLS ###

has 'source_path' =>
(
	qw(:ro),
	documentation => 'Path to the source file for this post',
);

has 'path' =>
(
	qw(:ro),
	documentation => 'Path to the location where the post should be published',
);

has 'url' => 
(
	qw(:ro),
	documentation => 'The absolute URL of this post in the website',
);


has 'tag_url' => 
(
	qw(:ro),
	documentation => 'Tag URL for this post, to be used e.g. in Atom feeds',
);	

### CONSTRUCTORS ###

sub new_from_id
{
	my ($class, $cfg, $id) = @_;

	# get contents of source file
	my $source_path = file(_inflate_source_path_from_id($id));

	# split sourcefile into sections
	my ($body, $teaser, $source, $meta) = _parse_source_file($source_path);

	# parse metadata
	my %meta = _parse_meta($meta);

	# expand metadata into objects
	my $author = _inflate_object_from_id('author', $cfg, $meta{type});
	my $topics = _inflate_object_from_id('topics', $cfg, $meta{type});
	my $type = _inflate_object_from_id('type', $cfg, $meta{type});
	
	# prepare the remaining attributes
	my $title = $meta{title};
	my $published = $meta{'published'} ? Miril::DateTime->new(iso2time($meta{'published'})) : undef;
	my $url = $meta{'published'} ? _inflate_url($id, $type, $published) : undef,
	my $path = _inflate_path_from_id($id, $type),
	
	return $class->new(
		id          => $id,
		title       => $title,
		author      => $author
		topics      => $topics,
		type        => $type,
		body        => $body,
		teaser      => $teaser,
		source      => $source,
		path        => $path,
		source_path => $filename,
		url         => $url,
		published   => $published,
	);
}

sub new_from_cache
{
	my ($class, $cfg, %cache) = @_;

	my $author = _inflate_object_from_id('author', $cfg, $cache{type});
	my $topics = _inflate_object_from_id('topics', $cfg, $cache{type});
	my $type = _inflate_object_from_id('type', $cfg, $cache{type});

	my $published = $cache{'published'} ? Miril::DateTime->new(iso2time($meta{'published'})) : undef;
	my $url = $cache{'published'} ? _inflate_url($id, $type, $published) : undef,

	return $class->new(
		id          => $cache{id},
		title       => $cache{title},
		author      => $author
		topics      => $topics,
		type        => $type,
		path        => file($cache{path}),
		source_path => file($cache{source_path}),
		url         => $url,
		published   => $published,
	);
}

sub new_from_params
{
	my ($class, $cfg, %params) = @_;

	my $author = _inflate_object_from_id('author', $cfg, $params{type});
	my $topics = _inflate_object_from_id('topics', $cfg, $params{type});
	my $type = _inflate_object_from_id('type', $cfg, $params{type});

	my $published = _inflate_date_published($params{published}, $params{status});

	return $class ->new(
		id        => $params{id},
		title     => $params{title},
		author    => $author,
		topics    => $topics,
		type      => $type,
		source    => $params{source},
		published => $published,
	);
}

### BUILDERS ###

sub _build_body
{
	my $self = shift;
	my ($source, $body, $teaser) = $self->_parse_source_file($self->source_path);
	$self->source($source);
	$self->teaser($teaser);
	return $body;
}

sub _build_source
{
	my $self = shift;
	my ($source, $body, $teaser) = $self->_parse_source_file($self->source_path);
	$self->body($body);
	$self->teaser($teaser);
	return $source;
}

sub _build_teaser
{
	my $self = shift;
	my ($source, $body, $teaser) = _parse_source_file($self->source_path);
	$self->source($source);
	$self->body($body);
	return $teaser;
}

### PRIVATE UTILITY FUNCTIONS ###

sub _parse_source_file 
{
	my $source_path = shift;

	my $post_file = $source_path->slurp or Miril::Exception->throw(
		message => "Cannot load data file",
		errorvar => $_,
	);

	my ($meta, $source) = split( /\n\n/, $post_file, 2);
	my ($teaser) = split( '<!-- BREAK -->', $source, 2);

	# temporary until we introduce multiple filters
	my $filter = Miril::Filter::Markdown->new;

	return $filter->to_xhtml($source), $filter->to_xhtml($teaser), $source, $meta;
}

sub _parse_meta 
{
	my ($meta) = @_;

	my @lines = split /\n/, $meta;
	my %meta;
	
	foreach my $line (@lines) {
		if ($line =~ /^(Published|Title|Type|Author|Status):\s+(.+)/) {
			my $name = lc $1;
			my $value = $2;
			$value  =~ s/\s+$//;
			$meta{$name} = $value;
		} elsif ($line =~ /Topics:\s+(.+)/) {
			my $value = lc $1;
			$value  =~ s/\s+$//;
			my @values = split /\s+/, $value;
			$meta{topics} = \@values;
		}
	}
	
	$meta{topics} = [] unless defined $meta{topics};

	return %meta;
}


1;
