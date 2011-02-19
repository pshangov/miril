package Miril::Store;

use strict;
use warnings;

use Syntax::Keyword::Gather;

use Mouse;
with 'WWW::Publisher::Static::Store';

has 'posts' =>
(
	is       => 'rw',
	isa      => 'HashRef[Miril::Post]',
	builder  => '_build_posts',
	lazy     => 1,
	traits   => ['Hash'],
	handles  => 
	{
		get_post_by_id => 'get',
		get_posts      => 'values',
		add_post       => 'set',
	},
);

has 'cfg' =>
(
	is       => 'ro',
	isa      => 'Miril::Config',
	required => 1,
);

has 'cache' =>
(
	is      => 'ro',
	isa     => 'Miril::Cache',
	lazy    => 1,
	builder => '_build_cache',
);

### BUILDERS ###

sub _build_cache
{
	my $self = shift;
	return Miril::Cache->new($self->cfg->cache_data)
}

sub _build_posts 
{
	my $self = shift;
	return [ map { Miril::Post->new_from_cache($self->cfg, %$_) } $self->cache->posts ];
}

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
			next if $params{'title'}  && $post->title    !~ /$title_rx/i;
			next if $params{'author'} && $post->author   ne $params{'author'};
			next if $params{'type'}   && $post->type->id ne $params{'type'};
			next if $params{'status'} && $post->status   ne $params{'status'};
			next if $params{'topic'}  && !first {$_->id eq $params{'topic'}} $post->get_topics;
			take $post;
		}
	};

	# sort
	if ($cfg->sort eq 'modified')
	{
		@posts = sort { $b->modified->epoch <=> $a->modified->epoch } @posts;
	}
	else
	{
		if ( first { !$_->published } @posts )
		{
			@posts = sort { $b->modified->epoch <=> $a->modified->epoch } @posts;
		}
		else
		{
			@posts = sort { $b->published->epoch <=> $a->published->epoch } @posts;
		}
	}
	
	# limit
	if ($params{'last'})
	{
		my $count = ( $params{'last'} < @posts ? $params{'last'} : @posts );
		splice @posts, $count;
	}

	return @posts;
}

sub save 
{
	my ($self, %params) = @_;

	my $post = Miril::Post->new_from_params($self->cfg, %params);
	$self->add_post($post->id => $post);

	# delete the old file if we have changed the id
	if ($params{old_id} and ($params{old_id} ne $params{id}))
	{
		$self->delete($params{old_id});
	}	

	# update the data file
	
	my $content = _generate_content($post);

	my $fh = $post->source_path->open('>') or Miril::Exception->throw(
		message => "Could not open data file for writing",
		erorvar => $_,
	);
	$fh->print($content);
	$fh->close;
}

sub delete
{
	my ($self, $id) = @_;

	my $post = $self->get_post_by_id($id);
	$post->remove or Miril::Exception->throw( 
		message => "Cannot delete post",
		errorvar => $_
	);
	
	$self->posts->delete($id);
}

sub get_latest 
{
	my ($self) = @_;
	
	my $cfg = $self->cfg;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['post'] );
	my $tree;
	my @posts;

	return [] unless -e $cfg->latest_data;
	
	try 
	{ 
		$tree = $tpp->parsefile( $cfg->latest_data );
		@posts = dao list $tree->{xml}{post};
	} 
	catch 
	{
		Miril::Exception->throw(
			message => "Could not get list of latest files",
			errorvar => $_,
		);
	};

	return \@posts;
}

sub add_to_latest 
{
	my ($self, $id, $title) = @_;

	my $cfg = $self->cfg;
    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['post'] );
	my $tree;
	my @posts;
	
	if ( -e $cfg->latest_data ) {
		try 
		{ 
			$tree = $tpp->parsefile( $cfg->latest_data );
			@posts = list $tree->{xml}{post};
		} 
		catch 
		{
			Miril::Exception->throw(
				message => "Could not add to list of latest files",
				errorvar => $),
			);
		};
	}

	@posts = grep { $_->{id} ne $id } @posts;
	unshift @posts, { id => $id, title => $title };
	@posts = @posts[0 .. 9] if @posts > 10;

	$tree->{xml}{post} = \@posts;
	
	try 
	{ 
		$tpp->writefile( $cfg->latest_data, $tree );
	} 
	catch
	{
			Miril::Exception->throw(
				message => "Could not write list of latest files",
				errorvar => $),
			);
		};
}

### PRIVATE FUNCTIONS ###

sub _generate_content
{
	my $post = shift;
	my $content;

	$content .= "Title: "     . $post->title          . "\n";
	$content .= "Type: "      . $post->type->id       . "\n";
	$content .= "Author: "    . $post->author         . "\n" if $post->author;
	$content .= "Published: " . $post->published->iso . "\n" if $post->published;
	$content .= "Topics: "    . join( " ", map { $_->id } $post->get_topics ) . "\n\n";

	$content .= $post->source;

	return $content;
}

1;
