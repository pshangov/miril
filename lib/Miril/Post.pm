package Miril::Post;

use strict;
use warnings;

use Mouse;
use Miril::TypeLib  qw(TextId Str Author ArrayRefOfTopic Type Status DateTime File Url TagUrl);
use Path::Class     qw(file dir);
use List::Util      qw(first);
use Class::Load     qw(load_class);
use Hash::MoreUtils qw(slice_def);
use Miril::DateTime;

### ID ###

has 'id' => 
(
	is            => 'ro',
	isa           => TextId,
	required      => 1,
	documentation => 'Unique text ID of the post',
);

### CONTENT ###

has 'title' => 
(
	is            => 'ro',
	isa           => Str,
	required      => 1,
	documentation => 'Post title',
);

has 'source' => 
(
	is            => 'rw',
	isa           => Str,
	lazy_build    => 1,
	documentation => 'Post body in the original markup format (e.g. Markdown, Textile)',
);

has 'body' =>
(
	is            => 'rw',
	isa           => Str,
	lazy          => 1,
	builder       => '_build_body',
	documentation => 'Post body in processed HTML',
);

has 'teaser' =>
(
	is            => 'rw',
	isa           => Str,
	lazy          => 1,
	builder       => '_build_teaser',
	documentation => 'Post teaser in processed HTML',
);

### METADATA ###

has 'author' => 
(
	is            => 'ro',
	isa           => Author,
	documentation => 'Post author',
);

has 'topics' => 
(
	is            => 'ro',
    isa           => ArrayRefOfTopic,
    #weak_ref     => 1,
    default       => sub { [] },
    traits        => ['Array'],
    handles       => { get_topics => 'elements' },
	documentation => 'List of Miril::Topic objects for this post',
);

has 'type' => 
(
	is            => 'ro',
	isa           => Type,
	required      => 1,
	weak_ref      => 1,
	handles       => { template => 'template' },
	documentation => 'Type of the post',
);

has 'status' =>
(
	is            => 'rw',
	isa           => Status,
	required      => 1,
    default       => 'draft',
	documentation => 'Post status: draft or published',
);

has 'published' => 
(
	is            => 'ro',
	isa           => DateTime,
    predicate     => 'is_published',
	trigger       => sub { $_[0]->status('published') },
	documentation => 'Time when the post was published',
);

has 'modified' => 
(
	is            => 'ro',
	isa           => DateTime,
    default       => sub { Miril::DateTime->now }, # for newly created posts
	documentation => 'Time when the post source post was last modified',
);

### PATHS ###

has 'source_path' =>
(
	is            => 'ro',
	isa           => File,
	documentation => 'Path to the source file for this post',
);

has 'path' =>
(
	is            => 'ro',
	isa           => File,
	documentation => 'Path to the location where the post should be published',
);

### CONSTRUCTORS ###

sub new_from_file
{
	my ($class, $file, $taxonomy) = @_;
    
	# split sourcefile into sections
	my ($source, $body, $teaser, $meta) = _parse_source_file($file);
    
	# parse metadata
	my %meta = _parse_meta($meta);

	# expand metadata into objects
	my $author = $taxonomy->get_author_by_id($meta{author}) if $meta{author};
	my $topics = $taxonomy->get_topics_by_id($meta{topics}) if @{$meta{topics}};
	my $type   = $taxonomy->get_type_by_id($meta{type})     if $meta{type};

	# get times
	my $published = $meta{'published'} ? Miril::DateTime->from_string($meta{'published'}) : undef;
    my $modified  = Miril::DateTime->from_epoch($file->stat->mtime);

    my $id = $file->basename;

    return $class->new( slice_def {
        id          => $id,
		title       => $meta{title},
		author      => $author,
        topics      => $topics,
		type        => $type,
		body        => $body,
		teaser      => $teaser,
		source      => $source,
		path        => $type->path($id),
		source_path => $file,
        published   => $published,
        modified    => $modified,
    } );
}

sub new_from_cache
{
	my ($class, $cache) = @_;
	return $class->new( slice_def $cache );
}

sub new_from_params
{
	my ($class, $params, $taxonomy, $data_path) = @_;

    my %params = %$params;

    my $author = $taxonomy->get_author_by_id($params{author}) if $params{author};
	my $topics = $taxonomy->get_topics_by_id($params{topics}) if $params{topics};
	my $type   = $taxonomy->get_type_by_id($params{type})     if $params{type};

    my $source_path = file($data_path, $params{id});

	my $published;

	if ($params{status} eq 'published')
	{
		$published = $params{published} 
			? Miril::DateTime->from_ymdhm($params{published}) 
			: Miril::DateTime->now;
	}

    my ($body, $teaser) = _parse_source($params{source});

	return $class->new( slice_def {
		id          => $params{id},
		title       => $params{title},
		author      => $author,
		topics      => $topics,
		type        => $type,
		source      => $params{source},
        body        => $body,
        teaser      => $teaser,
		published   => $published,
        source_path => $source_path,
    } );
}

### BUILDERS ###

sub _build_source
{
	my $self = shift;
	my ($source, $body, $teaser) = _parse_source_file($self->source_path);
	$self->body($body);
	$self->teaser($teaser);
	return $source;
}

sub _build_body
{
	my $self = shift;
    my ($source, $body, $teaser);

    if ($self->has_source)
    {
        ($body, $teaser) = _parse_source($self->source);
    }
    else
    {
        ($source, $body, $teaser) = _parse_source_file($self->source_path);
        $self->source($source);

    }

	$self->teaser($teaser);
	return $body;
}

sub _build_teaser
{
	my $self = shift;
    my ($body, $teaser);

    if ($self->has_source)
    {
        my ($body, $teaser) = _parse_source($self->source);
    }
    else
    {
        (my $source, $body, $teaser) = _parse_source_file($self->source_path);
        $self->source($source);

    }

	$self->body($body);
	return $teaser;
}

### PRIVATE UTILITY FUNCTIONS ###

# NOTE: All the functions below are pretty messy and should some day 
# be refactored into a proper standalone parser class ...

sub _parse_source_file
{
    my ($file, $format) = @_;

    my $source_file = $file->slurp or Miril::Exception->throw(
        message  => "Cannot load data file",
        errorvar => $_,
    );
    
    my ($meta, $source) = split( /\r?\n\r?\n/, $source_file, 2);
    
    my ($body, $teaser) = _parse_source($source);
    
    return $source, $body, $teaser, $meta;
}

sub _parse_source
{
	my ($source, $format) = @_;

	my ($teaser) = split( '<!-- BREAK -->', $source, 2);

    $format = 'markdown' unless $format;

    my %format_map = (
        markdown => 'Miril::Filter::Markdown',
    );
    
    load_class($format_map{$format});

    my $filter = $format_map{$format}->new;
	return $filter->to_xhtml($source), $filter->to_xhtml($teaser);
}

sub _parse_meta 
{
	my ($meta) = @_;

	my @lines = split /\n/, $meta;
	my %meta;
	
	foreach my $line (@lines) 
    {
		if ($line =~ /^(Published|Title|Type|Author|Status):\s+(.+)/) 
        {
			my $name = lc $1;
			my $value = $2;
			$value  =~ s/\s+$//;
			$meta{$name} = $value;
		} 
        elsif ($line =~ /Topics:\s+(.+)/) 
        {
			my $value = lc $1;
			$value  =~ s/\s+$//;
			my @values = split /\s+/, $value;
			$meta{topics} = \@values;
		}
	}
	
	$meta{topics} = [] unless defined $meta{topics};

	return %meta;
}

with 'Miril::Role::URL';

1;
