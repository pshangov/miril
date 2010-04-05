package Miril::Model::File;

use strict;
use warnings;

use Data::AsObject qw(dao);
use Hash::AsObject;
use File::Slurp;
use XML::TreePP;
use Try::Tiny qw(try catch);
use IO::File;
use File::Spec;
use List::Util qw(first);
use Miril::DateTime;
use Time::ISO::Simple qw(time2iso iso2time);
use Miril::Exception;
use Miril::Model::File::Post;

### ACCESSORS ###

use Object::Tiny qw(miril tpp tree);

### CONSTRUCTOR ###

sub new {
	my $self = bless {}, shift;
	$self->{miril} = shift;
	return $self;
}

### PUBLIC METHODS ###

sub get_post {
	my $self  = shift;
	my $id = shift;

	my $miril = $self->miril;
	my $cfg = $miril->cfg;

	my $filename = File::Spec->catfile($cfg->data_path, $id);
	my $post_file = File::Slurp::read_file($filename) 
		or $miril->process_error("Could not read data file", $!, 'fatal');

	my ($meta, $body) = split( /\n\n/, $post_file, 2);
	my ($teaser)      = split( '<!-- END TEASER -->', $body, 2);
    
	my %meta = _parse_meta($meta);

	# convert topic id's to topic objects
	my @topic_names = @{ $meta{topics} };

	if ( @topic_names ) {
		my %topics_lookup = map {$_ => 1} @topic_names;
		my @topic_objects = grep { $topics_lookup{$_->{id}} } $cfg->topics;
		$meta{topics} = \@topic_objects;
	}

	my $modified = time - ( (-M $filename) * 86400 );

	return Miril::Model::File::Post->new(
		id        => $id,
		title     => $meta{'title'},
		body      => $body,
		teaser    => $teaser,
		path      => $filename,
		modified  => Miril::DateTime->new($modified),
		published => Miril::DateTime->new(iso2time($meta{'published'})),
		type      => $meta{'type'},
		url       => $meta{'url'},
		author    => $meta{'author'},
		topics    => $meta{'topics'},
		format    => $meta{'format'},
	);
}

sub get_posts {
	my $self = shift;
	my $miril =  $self->miril;
	my $cfg = $miril->cfg;

	# read and parse cache file
	my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['post'] );
	$tpp->set( indent => 2 );
	$self->{tpp} = $tpp;
    
	my ($tree, @posts, $dirty);
	
	if (-e $cfg->cache_data) {
		try { 
			$tree = $tpp->parsefile( $cfg->cache_data );
		} catch {
			Miril::Exception->throw(
				message => "Could not read cache file", 
				erorvar => $!,
			);
		};
		@posts = map {
			Miril::Model::File::Post->new(
				id        => $_->{id},
				title     => $_->{title},
				path      => $_->{path},
				modified  => Miril::DateTime->new($_->{modified}),
				published => Miril::DateTime->new($_->{published}),
				type      => $_->{type},
				url       => $_->{url}, # TODO
				author    => $_->{author},
				topics    => $_->{topics},
				format    => $cfg->{format}, # TODO
			);
		} @{ $tree->{xml}{post} };
	} else {
		# miril is run for the first time
		$tree = {};
	}

	my @post_ids;

	# for each post, check if the data in the cache is older than the data in the filesystem

	foreach my $post (@posts) {
		if ( -e $post->path ) {
			push @post_ids, $post->id;
			my $modified = time - ( (-M $post->path) * 86400 );
			if ( $modified > $post->modified->epoch ) {
				$post = $self->get_post($post->id);
				$dirty++;
			}
		} else {
			undef $post;
			$dirty++;
		}
	}
	
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
	if ($dirty) {
		my $new_tree = $tree;
		$new_tree->{xml}->{post} = \@posts;

		try { 
			$self->tpp->writefile($cfg->cache_data, $new_tree); 
		} catch { 
			Miril::Exception->throw(
				message => "Cannot update cache file", 
				errorvar => $_,
			);
		};
	}

	return @posts;
}

sub save {
	my $self = shift;
	my $post = Hash::AsObject->new(@_);

	my $miril = $self->miril;
	my $cfg = $miril->cfg;
	
	my @posts = $self->get_posts;

	if ($post->old_id) {
		# this is an update
		
		for (@posts) {
			if ($_->id eq $post->old_id) {
				$_->{id}            = $post->id;
				$_->{author}        = $post->author;
				$_->{title}         = $post->title;
				$_->{topics}        = $post->topics;
				$_->{published}     = _set_publish_date($_->{published}, $post->status);
				$_->{status}        = $post->status;
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
					errorvar => $!
				);
			};
		}	

	} else {
		# this is a new post
		push @posts, Miril::Model::File::Post->new(
			id        => $post->id,
			author    => $post->author,
			title     => $post->title,
			type      => $post->type,
			topics    => { topic => [$post->topics] },
			published => _set_publish_date(undef, $post->status),
			status    => $post->status,
		);
		
	}
	
	# update the cache file

	my $new_tree = {};
	$new_tree->{xml}->{post} = \@posts;
	$self->{tree} = $new_tree;
	$self->tpp->writefile($cfg->cache_data, $new_tree) 
		or $miril->process_error("Cannot update cache file", $!, 'fatal');
	
	# update the data file
	my $content;

	$post = first { $_->id eq $post->id } @posts;

	$content .= ucfirst $_ . ": " . $post->{$_} . "\n"  for qw(title type author);
	$content .= "Published: " . ( $post->published ? $post->published->iso : '' ) . "\n";
	$content .= "Format: " . $cfg->format . "\n";
	$content .= "Topics: " . join(" ", @{ $post->topics }) . "\n\n";
	$content .= $post->body;

	my $fh = IO::File->new( File::Spec->catfile($cfg->data_path, $post->id), "w")
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->print($content)
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->close;
}

sub get_latest {
	my $self = shift;
	
	my $cfg = $self->miril->cfg;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	my $tree;
	my @items;
	
	try { 
		$tree = $tpp->parsefile( $cfg->latest_data );
		# force array
		@items = dao @{ $tree->{xml}{item} };
	} catch {
		$self->process_error($_);
	};
	

	return \@items;
}

sub add_to_latest {
	my $self = shift;
	my $cfg = $self->miril->cfg;

	my ($id, $title) = @_;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	my $tree;
	my @items;
	
	if ( -e $cfg->latest_data ) {
		try { 
			$tree = $tpp->parsefile( $cfg->latest_data );
			@items = @{ $tree->{xml}->{item} };
		} catch {
			$self->process_error($_);
		};
	}

	@items = grep { $_->{id} ne $id } @items;
	unshift @items, { id => $id, title => $title};
	@items = @items[0 .. 9] if @items > 10;

	$tree->{xml}{item} = \@items;
	
	try { 
		$tpp->writefile( $cfg->latest_data, $tree );
	} catch {
		$self->process_error("Failed to include in latest used", $_);
	};
}

### PRIVATE METHODS ###

sub _parse_meta {
	my $meta = shift;
	my @lines = split /\n/, $meta;
	my %meta;
	
	foreach my $line (@lines) {
		if ($line =~ /^(Published|Title|Type|Format|Author|Status):\s+(.+)/) {
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

sub _set_publish_date {
	my ($old_date, $new_status) = @_;
	return unless $new_status eq 'published';

	return $old_date 
		? Miril::DateTime->new(iso2time($old_date)) 
		: Miril::DateTime->new(time);
}

1;
