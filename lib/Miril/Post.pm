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
	trigger       => sub { $_[0]->status('published') },
	documentation => 'Time when the post was published',
);

has 'modified' => 
(
	is            => 'ro',
	isa           => DateTime,
	documentation => 'Time when the post source post was last modified',
);

### PATHS AND URLS ###

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

has 'url' => 
(
	is            => 'ro',
	isa           => Url,
	documentation => 'The absolute URL of this post in the website',
);


has 'tag_url' => 
(
	is            => 'ro',
	isa           => TagUrl,
	documentation => 'Tag URL for this post, to be used e.g. in Atom feeds',
);	

### CONSTRUCTORS ###

sub new_from_file
{
	my ($class, $file, %options) = @_;
    
    my ($taxonomy, $output_path, $base_url) = @options{qw(taxonomy output_path base_url)};

	# split sourcefile into sections
	my ($source, $body, $teaser, $meta) = _parse_source_file($file);

	# parse metadata
	my %meta = _parse_meta($meta);

	# expand metadata into objects
	my $author = $taxonomy->get_author_by_id($meta{author});
	my $topics = $taxonomy->get_topics_by_id($meta{topics});
	my $type   = $taxonomy->get_type_by_id($meta{type});

	# prepare the remaining attributes
	my $id        = $file->basename;
	my $title     = $meta{title};
	my $published = $meta{'published'} ? Miril::DateTime->from_string($meta{'published'}) : undef;
    my $modified  = Miril::DateTime->from_epoch($file->stat->mtime);
	my $url       = $base_url . $type->id . "/$id.html";
	my $path      = file($output_path, $type->location, $id . ".html");

    my $tag_url; 
    #tag:www.mechanicalrevolution.com,2011-05-02:/parameter_apocalypse_take_two

    if ($published)
    {
        my $base_url_sans_protocol = $base_url;
        $base_url_sans_protocol =~ s/^https?:\/\///;
        $base_url_sans_protocol =~ s/\/$//;

        $tag_url = sprintf('tag:%s,%s:/%s', 
            $base_url_sans_protocol,
            $published->as_strftime('%Y-%m-%d'),
            $id,
        );
    }

    return $class->new( slice_def {
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
        tag_url     => $tag_url,
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
	my ($class, $params, %options ) = @_;

    my %params = %$params;
    my $taxonomy = $options{taxonomy};

    my $author = $taxonomy->get_author_by_id($params{author});
	my $topics = $taxonomy->get_topics_by_id($params{topics});
	my $type   = $taxonomy->get_type_by_id($params{type});

	my $published;

	if ($params{status} eq 'published')
	{
		$published = $params{published} 
			? Miril::DateTime->from_epoch($params{published}) 
			: Miril::DateTime->now;
	}

    my ($body, $teaser) = _parse_source($params{source});

	return $class->new( slice_def {
		id        => $params{id},
		title     => $params{title},
		author    => $author,
		topics    => $topics,
		type      => $type,
		source    => $params{source},
        body      => $body,
        teaser    => $teaser,
		published => $published,
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

    my ($meta, $source) = split( /\n\n/, $source_file, 2);
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

1;
