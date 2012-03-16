package Miril::Store;

use strict;
use warnings;

use Mouse;
use Syntax::Keyword::Gather qw(gather take);
use List::Util              qw(first);
use Path::Class             qw(file);

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
    @posts = _sort_posts(@posts);

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

    # FIXME $self->data_dir is not required to build the post, can we add it later?
	my $post = Miril::Post->new_from_params( \%params, $self->taxonomy, $self->data_dir );
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

sub get_sorted_posts
{
    my $self = shift;
    return _sort_posts($self->get_posts);
    
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

sub _sort_posts
{
    my @posts = @_;

    my (@published, @not_published);

    foreach my $post (@posts)
    {
        if ($post->status eq 'published')   
        {
            push @published, $post;
        }
        else
        {
            push @not_published, $post;
        }
    }

    @not_published = sort { $b->modified->as_epoch <=> $a->modified->as_epoch   } @not_published;
    @published     = sort { $b->published->as_epoch <=> $a->published->as_epoch } @published;

    return @not_published, @published;
}

1;
