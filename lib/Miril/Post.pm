package Miril::Post;

# ABSTRACT: Post object

use strict;
use warnings;

use Mouse;
use Miril::TypeLib  qw(TextId Str Author ArrayRefOfTopic Type Status DateTime File Url TagUrl);
use Path::Class     qw(file dir);
use List::Util      qw(first);
use Class::Load     qw(load_class);
use Hash::MoreUtils qw(slice_def slice_grep);
use Carp            qw(croak);
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

has 'fields' => (
	is      => 'ro',
	isa     => 'HashRef',
	traits  => ['Hash'],
	handles => { field => 'get', has_field => 'exists', field_list => 'keys' },
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
	my %meta = _parse_meta($meta, $taxonomy);

	# expand metadata into objects
	my $type      = $taxonomy->type($meta{type});
	my $published = $meta{'published'} ? Miril::DateTime->from_string( $meta{'published'} ) : undef;
    my $modified  = Miril::DateTime->from_epoch($file->stat->mtime);
    my $id        = $file->basename;

    return $class->new( slice_def {
        id          => $id,
		title       => $meta{title},
        fields      => $meta{fields},
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

	my $type = $taxonomy->type($params{type}) if $params{type};
    my $source_path = file($data_path, $params{id});
    my ($body, $teaser) = _parse_source($params{source});

	my $published;

	if ($params{status} eq 'published')
	{
		$published = $params{published} 
			? Miril::DateTime->from_ymdhm($params{published}) 
			: Miril::DateTime->now;
	}

    my %fields;

    foreach my $key ( keys %params ) {
        next unless $type->has_field($key);
        $fields{$key} = $taxonomy->field($key)->process($params{$key});
    }

	return $class->new( slice_def {
		id          => $params{id},
		title       => $params{title},
        fields      => \%fields,
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
	my ($meta, $taxonomy) = @_;

	my @lines = split /\n/, $meta;
	my %meta;
	
	foreach my $line (@lines) 
    {
		if ( $line =~ /^([^:]+):(?:\s+(.+))?/ )
		{
			my ($name, $value) = ($1, $2);
			
            if ( $name =~ /^(Type|Title|Published)$/ ) 
            {
                $meta{lc($name)} = $value;
            }
			elsif ( my $field = $taxonomy->get_field_named($name) )
			{
				$meta{fields}{$field->id} = $field->process($value);
			}
			else
			{
				croak "No field named '$name' deifned.";
			}
		}
		else
		{
			croak "Failed parsing metadata statement '$line'.";
		}
	}

	if ( $meta{type} and my $type = $taxonomy->type($meta{type}) ) {
		foreach my $key ( keys %{ $meta{fields} }) {
			delete $meta{fields}{$key} unless $type->has_field($key);
		}
	} else {
		croak "Could not load type '$meta{type}'";
	}


	return %meta;
}

with 'Miril::Role::URL';

1;
