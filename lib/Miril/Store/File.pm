package Miril::Store::File;

use strict;
use warnings;

use autodie;
use Data::AsObject qw(dao);
use File::Slurp;
use XML::TreePP;
use Try::Tiny qw(try catch);
use IO::File;
use File::Spec;
use List::Util qw(first);
use Ref::List::AsObject qw(list);
use Miril::DateTime;
use Miril::DateTime::ISO::Simple qw(time2iso iso2time);
use Miril::Exception;
use Miril::Store::File::Post;
use File::Spec::Functions qw(catfile);
use Miril::URL;
use Syntax::Keyword::Gather qw(gather take);
use Data::Dumper qw(Dumper);

### ACCESSORS ###

use Object::Tiny qw(miril tpp tree);

### CONSTRUCTOR ###

sub new 
{
	my ($class, $miril) = @_;

	my $self = bless {}, $class;
	$self->{miril} = $miril;
	return $self;
}

### PUBLIC METHODS ###

sub get_post 
{
	my ($self, $id) = @_;

	my $miril = $self->miril;
	my $cfg = $miril->cfg;
	my $util = $miril->util;

	my $filename = $util->inflate_in_path($id);
	my $post_file;
	
	try
	{
		$post_file = File::Slurp::read_file($filename);
	}
	catch
	{
		Miril::Exception->throw(
			message => "Could not read data file", 
			errorvar => $_,
		);
	};

	my ($meta, $body) = split( /\n\n/, $post_file, 2);
	my ($teaser)      = split( '<!-- END TEASER -->', $body, 2);
    
	my %meta = _parse_meta($meta);

	my $modified = $util->inflate_date_modified($filename);
	my $type = $util->inflate_type($meta{'type'});

	return Miril::Store::File::Post->new(
		id        => $id,
		title     => $meta{'title'},
		body      => $body,
		teaser    => $teaser,
		out_path  => $util->inflate_out_path($id, $type),
		in_path   => $filename,
		modified  => Miril::DateTime->new($modified),
		published => $meta{'published'} ? Miril::DateTime->new(iso2time($meta{'published'})) : undef,
		type      => $type,
		url       => $util->inflate_post_url($id, $type),
		author    => $util->inflate_author($meta{'author'}),
		topics    => $util->inflate_topics( list $meta{'topics'} ),
	);
}

sub get_posts 
{
	my ($self, %params) = @_;

	my $miril =  $self->miril;
	my $cfg = $miril->cfg;
	my $util = $miril->util;

	# read and parse cache file
	my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['post', 'topic'] );
	$tpp->set( indent => 2 );
	$self->{tpp} = $tpp;
    
	my ($tree, @posts, $dirty);
	
	if (-e $cfg->cache_data) {
		try 
		{ 
			$tree = $tpp->parsefile( $cfg->cache_data );
		} catch {
			Miril::Exception->throw(
				message => "Could not read cache file", 
				erorvar => $_,
			);
		};
		@posts = map {
			my $type = $util->inflate_type($_->type);
			my @topics = list $_->topics->topic if $_->topics;
			
			Miril::Store::File::Post->new(
				id        => $_->id,
				title     => $_->title,
				in_path   => $util->inflate_in_path($_->id),
				out_path  => $util->inflate_out_path($_->id, $type),
				modified  => Miril::DateTime->new($_->modified),
				published => Miril::DateTime->new($_->published),
				type      => $type,
				author    => $util->inflate_author($_->author),
				topics    => $util->inflate_topics(@topics),
				url       => $util->inflate_post_url($_->id, $type),
			);
		} dao list $tree->{xml}{post};
	} else {
		# miril is run for the first time
		$tree = {};
	}

	my @post_ids;

	# for each post, check if the data in the cache is older than the data in the filesystem
	foreach my $post (@posts) {
		if ( -e $post->in_path ) {
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
	
	# check for entries missing from the cache
	opendir(my $data_dir, $cfg->data_path);
	while ( my $id = readdir($data_dir) ) {
		next if -d $id;
		unless ( first {$_ eq $id} @post_ids ) {
			my $post = $self->get_post($id);
			push @posts, $post;
			$dirty++;
		}
	}
	
	while ( my $id = readdir($data_dir) ) {
		next if -d $id;
		unless ( first {$_ eq $id} @post_ids ) {
			my $post = $self->get_post($id);
			push @posts, $post;
			$dirty++;
		}
	}

	# update cache file
	if ($dirty) {
		my $new_tree = $tree;
		$new_tree->{xml}{post} = _generate_cache_hash(@posts);

		try { 
			$self->tpp->writefile($cfg->cache_data, $new_tree); 
		} catch { 
			Miril::Exception->throw(
				message => "Cannot update cache file", 
				errorvar => $_,
			);
		};
	}

	# filter posts
	if (%params)
	{
		return gather 
		{
			for my $cur_post (@posts)
			{
				my $title_rx = $params{'title'};
				next if $params{'title'}  && $cur_post->title    !~ /$title_rx/i;
				next if $params{'author'} && $cur_post->author   ne $params{'author'};
				next if $params{'type'}   && $cur_post->type->id ne $params{'type'};
				next if $params{'status'} && $cur_post->status   ne $params{'status'};
				next if $params{'topic'}  && !first {$_->id eq $params{'topic'}} list $cur_post->topics;
				take $cur_post;
			}
		};
	} 
	else
	{
		return @posts;
	}
}

sub save 
{
	my ($self, %post) = @_;

	my $post = dao \%post;
	my $miril = $self->miril;
	my $cfg = $miril->cfg;
	my $util = $miril->util;
	
	my @posts = $self->get_posts;
	
	if ($post->old_id) {
		# this is an update

		for (@posts) {
			if ($_->id eq $post->old_id) {
				$_->{id}        = $post->id;
				$_->{author}    = $post->author;
				$_->{title}     = $post->title;
				$_->{type}      = $util->inflate_type($post->type);
				$_->{topics}    = $util->inflate_topics(list $post->topics);
				$_->{published} = $util->inflate_date_published($_->published->epoch, $post->status);
				$_->{status}    = $post->status;
				$_->{body}      = $post->body;
				last;
			}
		}
		
		# delete the old file if we have changed the id
		if ($post->old_id ne $post->id) {
			try {
				unlink($cfg->data_path . '/' . $post->old_id);
			} catch {
				Miril::Exception->throw( 
					message => "Cannot delete old version of renamed post",
					errorvar => $_
				);
			};
		}	

	} else {
		# this is a new post
		push @posts, Miril::Store::File::Post->new(
			id        => $post->id,
			author    => $post->author,
			title     => $post->title,
			type      => $util->inflate_type($post->type),
			topics    => $util->inflate_topics($post->topics),
			published => $util->inflate_date_published(undef, $post->status),
			status    => $post->status,
			body      => $post->body,
		);
	}

	# update the cache file
	my $new_tree;
	$new_tree->{xml}{post} = _generate_cache_hash(@posts);
	$self->{tree} = $new_tree;

	try
	{
		$self->tpp->writefile($cfg->cache_data, $new_tree)
	}
	catch
	{
		Miril::Exception->throw(
			message => "Could noe update cache file", 
			erorvar => $_,
		);
	};
	
	# update the data file
	my $content;
	
	$post = first { $_->id eq $post->id } @posts;

	$content .= ucfirst $_ . ": " . $post->{$_} . "\n"  for qw(title author);
	$content .= "Type: " . $post->type->id . "\n";
	$content .= "Published: " . $post->published->iso . "\n" if $post->published;
	$content .= "Topics: " . join(" ", map { $_->id } list $post->topics) . "\n\n";
	$content .= $post->body;

	try
	{
		my $fh = IO::File->new( catfile($cfg->data_path, $post->id), "w");
		$fh->print($content);
		$fh->close;
	}
	catch
	{
		Miril::Exception->throw(
			message => "Could not update data file", 
			erorvar => $_,
		);
	};
}

sub delete
{
	my ($self, $id) = @_;

	try
	{
		unlink catfile($self->miril->cfg->data_path, $id);
	}
	catch
	{
		Miril::Exception->throw(
			message => "Could not delete data file", 
			erorvar => $_,
		);
	};
}

sub get_latest 
{
	my ($self) = @_;
	
	my $cfg = $self->miril->cfg;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['post'] );
	my $tree;
	my @posts;
	
	try 
	{ 
		$tree = $tpp->parsefile( $cfg->latest_data );
		@posts = dao list $tree->{xml}{post};
	} 
	catch 
	{
		Miril::Exception->throw(
			message => "Could not get list of latest files",
			errorvar => $),
		);
	};
	

	return \@posts;
}

sub add_to_latest 
{
	my ($self, $id, $title) = @_;

	my $cfg = $self->miril->cfg;
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

sub _parse_meta 
{
	my ($meta) = @_;

	my @lines = split /\n/, $meta;
	my %meta;
	
	foreach my $line (@lines) {
		if ($line =~ /^(Published|Title|Type|Author|Status):\s+(.+)/) {
			my $name = lc $1;
			my $value = $2;
			$value  =~ s/\s+$//;
			$meta{$name} = $value;
		} elsif ($line =~ /Topics:\s+(.+)/) {
			my $value = lc $1;
			$value  =~ s/\s+$//;
			my @values = split /\s+/, $value;
			$meta{topics} = \@values;
		}
	}
	
	$meta{topics} = [] unless defined $meta{topics};

	return %meta;
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
