package Miril::Post;

use strict;
use warnings;

use Any::Moose;

with 'WWW::Publisher::Static::Post';

has 'id' => 
(
	qw(:ro :required),
	isa           => 'Str',
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
	default       => 'draft'
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

### LAZY LOADING OF SOURCE, BODY AND TEASER ###

sub _build_body
{
	my $self = shift;
	my ($source, $body, $teaser) = $self->_populate;
	$self->source($source);
	$self->teaser($teaser);
	return $body;
}

sub _build_source
{
	my $self = shift;
	my ($source, $body, $teaser) = $self->_populate;
	$self->body($body);
	$self->teaser($teaser);
	return $source;
}

sub _build_teaser
{
	my $self = shift;
	my ($source, $body, $teaser) = $self->_populate;
	$self->source($source);
	$self->body($body);
	return $teaser;
}

sub _populate 
{
	my $self = shift;

	my $post_file = try {
		File::Slurp::read_file($self->path);
	} catch {
		Miril::Exception->throw(
			message => "Cannot load data file",
			errorvar => $_,
		);
	};

	my ($meta, $source) = split( /\n\n/, $post_file, 2);
	my ($teaser) = split( '<!-- BREAK -->', $source, 2);

	# temporary until we introduce multiple filters
	my $filter = Miril::Filter::Markdown->new;

	return $filter->to_xhtml($source), $filter->to_xhtml($teaser), $source;
}

1;
