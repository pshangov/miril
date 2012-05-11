package Miril::Cache;

# ABSTRACT: Cache posts for speedier loading

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

has 'taxonomy' => 
(
    is       => 'ro',
    isa      => 'Miril::Taxonomy',
    required => 1,    
);

sub _build_raw
{
    my $self = shift;
    my $filename = $self->filename;

    if ( -e $filename)
    {
	    return Storable::retrieve($filename);
    }
    else
    {
        return {};
    }
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
			$self->add_post( Miril::Post->new_from_file( $id, $self->taxonomy ) );
		}
	}

    foreach my $id ( $self->data_dir->children( no_hidden => 1 ) ) 
	{
		next if -d $id;
		unless ( $self->exists_in_cache($id->basename) )
		{
            $posts{$id->basename} = Miril::Post->new_from_file( $id, $self->taxonomy );
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
            source_path => $post->source_path,
            fields      => $post->fields,
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
