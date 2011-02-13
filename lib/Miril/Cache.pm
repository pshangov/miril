package Miril::Cache;

use Moose;
use XML::TreePP;
use Data::AsObject;
use Miril::Post;

has 'path' =>
(
	qw(:ro :required),
	isa => 'File',
);

has 'is_full' =>
(
	qw(:ro :lazy_build),
	isa => 'Bool',
);

has 'requires_update' =>
(
	qw(:rw :lazy_build),
	isa => 'Bool',
);

has 'entries' =>
(
	qw(:rw),
	isa     => 'ArrayRef',
	traits  => ['Array'],
	handles => { elements => 'get_entries' },
	builder => '_build_entries',
);

has 'tree' =>
(
	qw(:rw),
	builder => '_build_tree',
);

has 'tpp' =>
(
	qw(:rw),
	builder => '_build_tpp',
);

has 'ivalid_entries' =>
(
	qw(:rw),
	isa    => 'ArrayRef',
	traits => ['Array'],
);

sub _build_entries
{
	my $self = shift;

	my @posts = map 
	{
		my $type = $util->inflate_type($_->type);
		my @topics = $_->topics->topic->list if $_->topics;
		
		Miril::Post->new(
			id        => $_->id,
			title     => $_->title,
			in_path   => $util->inflate_in_path($_->id),
			out_path  => $util->inflate_out_path($_->id, $type),
			modified  => Miril::DateTime->new($_->modified),
			published => $_->published ? Miril::DateTime->new($_->published) : undef,
			type      => $type,
			author    => $util->inflate_author($_->author),
			topics    => $util->inflate_topics(@topics),
			url       => $_->published ? $util->inflate_post_url($_->id, $type, Miril::DateTime->new($_->published)) : undef,
		);
	} dao list $self->tree->{xml}{post};

	# check for outdated stuff
	foreach my $post (@posts) {
		if ( -e $post->source_path ) {
			push @post_ids, $post->id;
			
			my $modified = $util->inflate_date_modified($post->in_path);
			if ( $modified > $post->modified->epoch ) {
				$post = $self->get_post($post->id);
				$dirty++;
			}
		} else {
			undef $post;
			$dirty++;
		}
	}

	# clean up posts deleted from the cache
	@posts = grep { defined } @posts;

	# check for missing stuff
	
	while ( my $id = readdir($data_dir) ) {
		next if -d $id;
		unless ( first {$_ eq $id} @post_ids ) {
			my $post = $self->get_post($id);
			push @posts, $post;
			$dirty++;
		}
	}

	return @posts;
}

sub _build_tpp
{
	my $self = shift;

	my $tpp = XML::TreePP->new();
	
	$tpp->set( force_array => ['post', 'topic'] );
	$tpp->set( indent => 2 );
	return $tpp;
}

sub _build_tree
{
	my $self = shift;
	
	if (-e $self->path) 
	{
		return $self->tpp->parsefile( $self->path ) or
			Miril::Exception->throw(
				message => "Could not read cache file", 
				erorvar => $!,
			);
	}
	else
	{
		$self->posts([]);
		return {};
	}
}

sub update
{
	my $self = shift;

	return unless $self->requires_update;

	$self->tree->{xml}{post} = _generate_cache_hash($self->get_entries);

	$self->tpp->writefile($self->path, $self->tree) or
		Miril::Exception->throw(
			message => "Cannot update cache file", 
			errorvar => $!,
		);
}

sub _generate_cache_hash
{
	my (@posts) = @_;

	my @cache_posts = map {{
		id        => $_->id,
		title     => $_->title,
		modified  => $_->modified ? $_->modified->epoch : Miril::DateTime->new(time)->epoch,
		published => $_->published ? $_->published->epoch : undef,
		type      => $_->type->id,
		author    => $_->author,
		topics    => { topic => [ map {$_->id} list $_->topics ] },
	}} @posts;

	return \@cache_posts;
}

1;
