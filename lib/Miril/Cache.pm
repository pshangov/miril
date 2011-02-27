package Miril::Cache;

use Mouse;
use Miril::Post;
use Storable ();

has 'filename' => (
	is  => 'ro',
	isa => 'Path::Class::File',
);

has 'raw' => (
	is      => 'ro',
	isa     => 'HashRef',
	lazy    => 1,
	builder => '_build_raw',
	traits  => ['Hash'],
	handles => { cached_ids => 'values', get_cached_post => 'get' },
);

has 'posts' => (
	is      => 'ro',
	isa     => 'HashRef[Miril::Post]',
	lazy    => 1,
	builder => '_build_posts',
	traits  => ['Hash'],
	handles => { post_ids => 'values', get_post_by_id => 'get' },
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
		if ( ! -e $post{$id}->source_path )
		{
			$self->delete_post($id);
		}
		# post has been updated
		elsif ( ( time - ( -M $post->source_path ) * 86400 ) > $post->modified->epoch )
		{
			$self->add_post(Miril::Post->new_from_id($id));
		}
	}

	while ( my $id = readdir($self->data_dir) ) 
	{
		next if -d $id;
		unless ( $self->exists_post($id) )
		{
			$self->add_post( Miril::Post->new_from_id($id) );
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
			id        => $post->id,
			title     => $post->title,
			modified  => $post->modified->epoch,
			published => $post->published ? $post->published->epoch : undef,
			type      => $post->type->id,
			author    => $post->author->id,
			topics    => [ map { $_->id } $post->get_topics ],
		};
	}
}

sub update
{
	Storable::store($_[0]->serialize, $_[0]->filename);
}

1;
