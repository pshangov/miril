package Miril::Cache;

use Mouse;
use Miril::Post;
use Storable ();

has 'filename' => (
	is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

has 'raw' => (
	is      => 'ro',
	isa     => 'HashRef',
	lazy    => 1,
	builder => '_build_raw',
	traits  => ['Hash'],
	handles => { 
        cached_ids      => 'keys', 
        get_cached_post => 'get',
        exists_in_cache => 'exists',
    },
);

has 'posts' => (
	is      => 'ro',
	isa     => 'HashRef[Miril::Post]',
	lazy    => 1,
	builder => '_build_posts',
	traits  => ['Hash'],
	handles => { 
        post_ids       => 'keys', 
        get_posts      => 'values', 
        get_post_by_id => 'get',
        add_post       => 'set',
        delete_post    => 'delete',
    },
);

has 'data_dir' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
);

sub _build_raw
{
	return Storable::retrieve($_[0]->filename);
}

sub _build_posts
{
	my $self = shift;
	my %posts;

	foreach my $id ($self->cached_ids)
	{
		my $cached = $self->get_cached_post($id);
		$posts{$id} = Miril::Post->new_from_cache($cached);
	}

	while ( my ($id, $post) = each %posts )
	{
		# post has been deleted
		if ( not -e $posts{$id}->source_path )
		{
            #TODO
            #$self->delete_post($id);
		}
		# post has been updated
		elsif ( $post->source_path->stat->mtime > $post->modified->as_epoch )
		{
			$self->add_post(Miril::Post->new_from_id($id));
		}
	}

    foreach my $id ( $self->data_dir->children( no_hidden => 1 ) ) 
	{
		next if -d $id;
		unless ( $self->exists_in_cache($id->basename) )
		{
            $posts{$id} = Miril::Post->new_from_file($id);
		}
	}

	return \%posts;
}

sub serialize
{
	my $self = shift;
	my %serialized;

	foreach my $post ($self->get_posts)
	{
		$serialized{$post->id} = {
			id          => $post->id,
			title       => $post->title,
			modified    => $post->modified,
			published   => $post->published,
            type        => $post->type,
            author      => $post->author,
            topics      => $post->topics,
            source_path => $post->source_path,
		};
	}

    return \%serialized;
}

sub update
{
    my $self = shift;
	Storable::store($self->serialize, $self->filename);
}

1;
