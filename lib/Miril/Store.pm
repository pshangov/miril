package Miril::Store;

use strict;
use warnings;

use File::Slurp;
use Syntax::Keyword::Gather qw(gather take);

use Mouse;
with 'WWW::Publisher::Static::Store';

has 'cfg' =>
(
	is       => 'ro',
	isa      => 'Miril::Config',
	required => 1,
);

has 'util' =>
(
	is       => 'ro',
	isa      => 'Miril::Util',
	required => 1,
);

has 'filter' =>
(
	is       => 'ro',
	isa      => 'Miril::Filter',
	required => 1,
);

has 'tpp' =>
(
	is       => 'rw',
	isa      => 'XML::TreePP',
);

has 'tree' =>
(
	is       => 'rw',
	isa      => 'HashRef',
);


### PUBLIC METHODS ###

sub get_post_by_id
{
	my ($self, $id) = @_;

	my $cfg = $self->cfg;
	my $util = $self->util;

	#TODO _inflate_source_path
	my $filename = $util->inflate_in_path($id);
	
	my $post_file = File::Slurp::read_file($filename) or
		Miril::Exception->throw(
			message => "Could not read data file", 
			errorvar => $_,
		);

	#TODO _post_parse_sections
	my ($meta, $source) = split( /\n\n/, $post_file, 2);
	my ($teaser)        = split( '<!-- BREAK -->', $source, 2);
    
	#TODO _post_parse_meta
	my %meta = _parse_meta($meta);

	#TODO _build_date_modified
	my $modified = $util->inflate_date_modified($filename);
	#TODO _inflate_type_from_id
	my $type = $util->inflate_type($meta{'type'});
	
	my $published = $meta{'published'} ? Miril::DateTime->new(iso2time($meta{'published'})) : undef;

	Miril::Post->new_with_cfg(
		id => $id,
		source => $source, # optional
		meta => $meta,
		cfg => $cfg,
	);

	# OR:
	
	return Miril::Store::File::Post->new(
		id        => $id,
		title     => $meta{'title'},
		body      => $self->filter->to_xhtml($source),
		teaser    => $self->filter->to_xhtml($teaser),
		source    => $source,
		path      => $util->inflate_out_path($id, $type),
		source_path => $filename,
		#modified  => Miril::DateTime->new($modified),
		published => $published,
		type      => $type,
		#TODO _inflate_url
		url       => $published ? $util->inflate_post_url($id, $type, $published) : undef,
		author    => $util->inflate_author($meta{'author'}),
		topics    => $util->inflate_topics( list $meta{'topics'} ),
	);
}

sub get_posts 
{
	my ($self, %params) = @_;

	my $cfg = $self->cfg;
	my $util = $self->util;

	my $cache = Miril::Cache->new($cfg->cache_data);

	if ($cache->is_full)
	{
		my @posts = map { ... } $cache->posts;
	}  

	my @post_ids;

	#TODO $cache->check_state;
	# for each post, check if the data in the cache is older than the data in the filesystem
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
	
	#TODO my $post = $self->get_post($_); push @posts, $cache->add_items($post) for $cache->posts_needing_update;
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
	

	# update cache file
	$self->cache->update;

	# filter posts
	if (%params)
	{
		@posts = gather 
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
	
	if ($params{'last'})
	{
		my $count = ( $params{'last'} < @posts ? $params{'last'} : @posts );
		splice @posts, $count;
	}

	return @posts;
}

sub save 
{
	my ($self, %post) = @_;

	my $post = dao \%post;
	my $cfg = $self->cfg;
	my $util = $self->util;
	
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
				$_->{status}    = $post->status;
				$_->{source}    = $post->source;
				if ($post->status eq 'published')
				{
					$_->{published} = $util->inflate_date_published($_->published, $post->status);
				}
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
		my $new_post = Miril::Store::File::Post->new(
			id        => $post->id,
			author    => ($post->author or undef),
			title     => $post->title,
			type      => $util->inflate_type($post->type),
			topics    => $util->inflate_topics($post->topics),
			published => $util->inflate_date_published(undef, $post->status),
			status    => $post->status,
			source    => $post->source,
		);
		push @posts, $new_post;
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

	$content .= "Title: " . $post->title . "\n";
	$content .= "Author: " . $post->author . "\n" if $post->author;
	$content .= "Type: " . $post->type->id . "\n";
	$content .= "Published: " . $post->published->iso . "\n" if $post->published;
	$content .= "Topics: " . join(" ", map { $_->id } list $post->topics) . "\n\n";
	$content .= $post->source;

	try
	{
		my $fh = IO::File->new( catfile($cfg->data_path, $post->id), "w") or die $!;
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
		unlink catfile($self->cfg->data_path, $id);
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


sub search {
if ( $list->match->id )
		{
			push @posts, $miril->store->get_post($_) for $list->match->id->list;
		}
		else 	
		{
			my @params = qw(
				author
				type
				status
				topic
				created_before
				created_on
				created_after
				updated_before
				updated_on
				updated_after
				published_before
				published_on
				published_after
				last
			);
		
			my %params;

			foreach my $param (@params) {
				if ( exists $list->match->{$param} ) {
					$params{$param} = $list->match->{$param};
				}
			}

			@posts = $miril->store->get_posts(%params);
		}
}

1;
