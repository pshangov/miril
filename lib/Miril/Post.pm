package Miril::Post;

use strict;
use warnings;
use Any::Moose;
use Path::Class;
use List::Util qw(first);
use Miril::DateTime;

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
	is            => 'ro',
	isa           => 'Str',
	required      => 1,
	documentation => 'Post title',
);

has 'source' => 
(
	is            => 'rw',
	isa           => 'Str',
	lazy          => 1,
	builder       => '_build_source',
	documentation => 'Post body in the original markup format (e.g. Markdown, Textile)',
);

has 'body' =>
(
	is            => 'rw',
	isa           => 'Str',
	lazy          => 1,
	builder       => '_build_body',
	documentation => 'Post body in processed HTML',
);

has 'teaser' =>
(
	is            => 'rw',
	isa           => 'Str',
	lazy          => 1,
	builder       => '_build_teaser',
	documentation => 'Post teaser in processed HTML',
);

### METADATA ###

has 'author' => 
(
	is            => 'ro',
	isa           => 'Str',
	documentation => 'Post author',
);

has 'topics' => 
(
	is            => 'ro',
	isa           => 'ArrayRef[Miril::Topic]',
	weak_ref      => 1,
	documentation => 'List of Miril::Topic objects for this post',
);

has 'type' => 
(
	is            => 'ro',
	isa           => 'Miril::Type',
	required      => 1,
	weak_ref      => 1,
	handles       => { template => 'template' },
	documentation => 'Type of the post',
);

has 'status' =>
(
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	builder       => '_build_status',
	documentation => 'Post status: draft or published',
);

has 'published' => 
(
	is            => 'ro',
	trigger       => sub { $_[0]->status('published') },
	documentation => 'Time when the post was published',
);

has 'modified' => 
(
	is            => 'ro',
	required      => 1,
	lazy          => 1,
	builder       => '_build_modified',
	documentation => 'Time when the post source post was last modified',
);

### PATHS AND URLS ###

has 'source_path' =>
(
	is            => 'ro',
	documentation => 'Path to the source file for this post',
);

has 'path' =>
(
	is            => 'ro',
	documentation => 'Path to the location where the post should be published',
);

has 'url' => 
(
	is            => 'ro',
	documentation => 'The absolute URL of this post in the website',
);


has 'tag_url' => 
(
	is            => 'ro',
	documentation => 'Tag URL for this post, to be used e.g. in Atom feeds',
);	

### CONSTRUCTORS ###

# requires output_path, base_url, authors, topics and types
sub new_from_file
{
	my ($class, $file) = @_;
	my ($output_path, $base_url, $cfg_authors, $cfg_topics, $cfg_types);

	# split sourcefile into sections
	my ($body, $teaser, $source, $meta) = _parse_source_file($file);

	# parse metadata
	my %meta = _parse_meta($meta);

	# expand metadata into objects
	my $author = _inflate_object_from_id('author', $cfg_types,   $meta{type});
	my $topics = _inflate_object_from_id('topics', $cfg_topics,  $meta{topics});
	my $type   = _inflate_object_from_id('type',   $cfg_authors, $meta{author});
	
	# prepare the remaining attributes
	my $id        = $file->basename;
	my $title     = $meta{title};
	my $published = $meta{'published'} ? Miril::DateTime->new_from_string($meta{'published'}) : undef;
	my $url       = $base_url . $type->id . "/$id.html";
	my $path      = file($output_path, $type->location, $id . ".html");
	
	return $class->new(
		id          => $id,
		title       => $title,
		author      => $author,
		topics      => $topics,
		type        => $type,
		body        => $body,
		teaser      => $teaser,
		source      => $source,
		path        => $path,
		source_path => $file,
		url         => $url,
		published   => $published,
	);
}

sub new_from_cache
{
	my ($class, %cache) = @_;
	my ($cfg_authors, $cfg_topics, $cfg_types);

	my $author = _inflate_object_from_id('author', $cfg_authors, $cache{author});
	my $topics = _inflate_object_from_id('topics', $cfg_topics,  $cache{topics});
	my $type   = _inflate_object_from_id('type',   $cfg_types,   $cache{type});

	my $published = $cache{'published'} ? Miril::DateTime->new_from_string($cache{'published'}) : undef;

	return $class->new(
		id          => $cache{id},
		title       => $cache{title},
		author      => $author,
		topics      => $topics,
		type        => $type,
		path        => file($cache{path}),
		source_path => file($cache{source_path}),
		url         => $cache{url},
		published   => $published,
	);
}

sub new_from_params
{
	my ($class, %params) = @_;
	my ($cfg_authors, $cfg_topics, $cfg_types);

	my $author = _inflate_object_from_id('author', $cfg_authors, $params{author});
	my $topics = _inflate_object_from_id('topics', $cfg_topics,  $params{topics});
	my $type   = _inflate_object_from_id('type',   $cfg_types,   $params{type});

	my $published;

	if ($params{status} eq 'published')
	{
		$published = $params{published} 
			? Miril::DateTime->new($params{published}) 
			: Miril::DateTime->now;
	}
	else
	{
		$published = undef;
	}

	return $class->new(
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

sub _inflate_object_from_id
{
	my ($type, $id, $list) = @_;

	return undef unless defined $id;

	if (!ref $id)
	{
		return first { $_->id eq $id } @$list;
	}
	elsif (ref $id eq 'ARRAY')
	{
		my @objects;
		return \@objects;
	}
}

1;
