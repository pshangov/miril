package Miril::Store;

use strict;
use warnings;

use Mouse;
use Syntax::Keyword::Gather qw(gather take);
use List::Util              qw(first);
use Path::Class             qw(file);

#has 'posts' =>
#(
#	is       => 'rw',
#	isa      => 'HashRef[Miril::Post]',
#	traits   => ['Hash'],
#	handles  => 
#	{
#		get_post_by_id => 'get',
#		get_posts      => 'values',
#		add_post       => 'set',
#	},
#);

has 'cache' =>
(
	is       => 'ro',
    required => 1,
	isa      => 'Miril::Cache',
    handles  => [qw(posts get_posts post_ids add_post delete_post get_post_by_id)],
);

has 'sort' =>
(
    is       => 'ro',
    required => 1,
    default  => 'modified',
);

has 'taxonomy' =>
(
    is       => 'ro',
    isa      => 'Miril::Taxonomy',
    required => 1,
    default  => 'modified',
);

has 'data_dir' =>
(
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
);

### PUBLIC METHODS ###

sub search
{
	my ($self, %params) = @_;

	return $self->get_posts unless %params;

	# search
	my @posts = gather 
	{
		foreach my $post ($self->get_posts)
		{
			my $title_rx = $params{'title'};
			next if $params{'title'}  && $post->title      !~ /$title_rx/i;
			next if $params{'author'} && $post->author->id ne $params{'author'};
			next if $params{'type'}   && $post->type->id   ne $params{'type'};
			next if $params{'status'} && $post->status     ne $params{'status'};
			next if $params{'topic'}  && !first {$_->id eq $params{'topic'}} $post->get_topics;
			take $post;
		}
	};

	# sort
	if ($self->sort eq 'modified')
	{
		@posts = sort { $b->modified->as_epoch <=> $a->modified->as_epoch } @posts;
	}
	else
	{
		if ( first { !$_->published } @posts )
		{
			@posts = sort { $b->modified->as_epoch <=> $a->modified->as_epoch } @posts;
		}
		else
		{
			@posts = sort { $b->published->epoch <=> $a->published->epoch } @posts;
		}
	}
	
	# limit
	if ($params{'limit'})
	{
		my $count = ( $params{'limit'} < @posts ? $params{'limit'} : @posts );
		splice @posts, $count;
	}

	return @posts;
}

sub save 
{
	my ($self, %params) = @_;

	my $post = Miril::Post->new_from_params( \%params, 
        taxonomy => $self->taxonomy,
        data_dir => $self->data_dir,
    );
	$self->add_post($post->id => $post);

	# delete the old file if we have changed the id
	if ($params{old_id} and ($params{old_id} ne $params{id}))
	{
		$self->delete($params{old_id});
	}	

	# update the data file
	my $content = _generate_content($post);

	my $fh = $post->source_path->open('>') or die $!;
	$fh->print($content)                   or die $!;
	$fh->close                             or die $!;
}

sub delete
{
	my ($self, $id) = @_;
    file( $self->data_dir, $id )->remove or die $!;
	$self->delete_post($id);
}

### PRIVATE FUNCTIONS ###

sub _generate_content
{
	my $post = shift;
	my $content;

	$content .= "Title: "     . $post->title          . "\n";
	$content .= "Type: "      . $post->type->id       . "\n";
	$content .= "Author: "    . $post->author->id     . "\n" if $post->author;
	$content .= "Published: " . $post->published->as_ymdhm . "\n" if $post->published;
	$content .= "Topics: "    . join( " ", map { $_->id } $post->get_topics ) . "\n\n";

	$content .= $post->source;

	return $content;
}

1;
