package Miril::Model::File;

use strict;
use warnings;

use Data::AsObject qw(dao);
use File::Slurp;
use XML::TreePP;
use Try::Tiny qw(try catch);
use IO::File;
use File::Spec;
use List::Util qw(first);
use Miril::DateTime;

# constructor
sub new {
	my $self = bless {}, shift;
	$self->{miril} = shift;
	return $self;
}

sub get_post {
	my $self  = shift;
	my $id = shift;

	my $miril = $self->miril;
	my $cfg = $miril->cfg;

	my $filename = File::Spec->catfile($cfg->data_path, $id);
	my $post_file = File::Slurp::read_file($filename) 
		or $miril->process_error("Could not read data file", $!, 'fatal');

	my ($meta, $body) = split( '<!-- END META -->', $post_file, 2);
	my ($teaser)      = split( '<!-- END TEASER -->', $body, 2);
    
	my %meta = _parse_meta($meta);

	# convert topic id's to topic objects
	my @topic_names = @{ $meta{topics} };

	if ( @topic_names ) {
		my %topics_lookup = map {$_ => 1} @topic_names;
		my @topic_objects = grep { $topics_lookup{$_->{id}} } $cfg->topics;
		$meta{topics} = \@topic_objects;
	}


	my $post = \%meta;

	$post->{id}       = $id;
	$post->{text}     = $body;
	$post->{teaser}   = $teaser;
	$post->{path}     = $filename;
	$post->{modified} = Miril::DateTime->new(-M $filename);

	return dao $post;
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
		$tree = $tpp->parsefile( $cfg->cache_data ) 
			or $miril->process_error("Could not read cache file", $!, 'fatal');
		@posts = dao( @{ $tree->{xml}{post} } );
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
			if ( $modified > $post->modified ) {
				my $updated_post = $self->get_post($post->id);
				for (qw(id published title type format author topics)) {
					$post->{$_} = $updated_post->{$_};
				}
				$post->{modified} = Miril::DateTime->new($modified);
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
			my $post;
			my $new_post = $self->get_post($id);
			for (qw(id published title type format author topics)) {
				$post->{$_} = $new_post->{$_};
			}
			my $path = File::Spec->catfile($cfg->data_path, $id);
			$post->{path} = $path;
			$post->{modified} = -M $path;
			push @posts, $post;
			$dirty++;
		}
	}

	# update cache file
	if ($dirty) {
		my $new_tree = $tree;
		$new_tree->{xml}->{post} = \@posts;
		$self->tpp->writefile($cfg->cache_data, $new_tree) 
			or $miril->process_error("Cannot update cache file", $!);
	}

	return @posts;
}

sub save {
	my $self = shift;
	my $post = dao shift;

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
			unlink($self->data_path . '/' . $post->old_id) 
				or $miril->process_error("Cannot delete old version of renamed post", $!);
		}	

	} else {
		# this is a new post
		my $new_item = dao {
			id        => $post->id,
			author    => $post->author,
			title     => $post->title,
			type      => $post->type,
			topics    => { topic => [$post->topics] },
			published => _set_publish_date(undef, $post->status),
			status    => $post->status,
		};
		
		push @posts, $new_item;
	}
	
	# update the cache file

	my $new_tree = {};
	$new_tree->{xml}->{post} = \@posts;
	$self->{tree} = $new_tree;
	$self->tpp->writefile($cfg->cache_data, $new_tree) 
		or $miril->process_error("Cannot update cache file", $!, 'fatal');
	
	# update the data file
	my $content;

	$content .= "$_: " . $post->{$_} . "\n"  for qw(published title type format author);
	$content .= "topics: " . join(" ", $post->topics) . "\n";
	$content .= "<!-- END META -->\n";
	$content .= $post->text;

	my $fh = IO::File->new( File::Spec->catfile($cfg->data_path, $post->id), "w")
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->print($content)
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->close;
}

sub _parse_meta {
	my $meta = shift;
	my @lines = split /\n/, $meta;
	my %meta;
	
	foreach my $line (@lines) {
		if ($line =~ /^(published|title|type|format|author|status):\s+(.+)/) {
			my $name = $1;
			my $value = $2;
			$value  =~ s/\s+$//;
			$meta{$name} = $value;
		} elsif ($line =~ /topics:\s+(.+)/) {
			my $value = $1;
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
	my $new_date = time2iso(time);
	
	return unless $new_status eq 'published';
	return($old_date ? $old_date : $new_date);
}

sub miril { shift->{miril} }
sub tpp   { shift->{tpp}   }
sub tree  { shift->{tree}  }

1;
