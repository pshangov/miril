package Miril::Model::File;

# constructor
sub new {}

sub get_post {
	my $self  = shift;
	my $id = shift;

	my $miril = $self->miril;
	my $cfg = $miril->cfg;

	my $filename = filename_from_id($id);
	my $post_file = File::Slurp::read_file($filename) 
		or $miril->process_error("Could not read data file", $!, 'fatal');

	my ($meta, $body) = split( '<!-- END META -->', $post_file, 2);
	my ($teaser)      = split( '<!-- END TEASER -->', $body, 2);
    
	my %meta = parse_meta($meta);

	my $post = \%meta;
	
	$post->{id} = $id;
	$post->{body} = $body;
	$post->{teaser} = $teaser;
	$post->{path} = $filename;
	$post->{modified} = -M $filename;

	return $post;
}

sub get_posts {
	my $self = shift;
	my $miril =  $self->miril;
	my $cfg = $miril->cfg;

	# read and parse cache file
	my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['post'] );
	$tpp->set( indent => 2 );
    
	my ($tree, @posts, $dirty);
	
	if (-e $cfg->cache) {
		$tree = $tpp->parsefile( $cfg->cache_data ) 
			or $miril->process_error("Could not read cache file", $!, 'fatal');
		@posts = dao @{ $tree->{xml}{post} };
	} else {
		# miril is run for the first time
		$tree = {};
	}
	my @post_ids;

	# for each post, check if the data in the cache is older than the data in the filesystem
	foreach my $post (@posts) {
		if ( -e $post->path ) {
			my $modified = -M $post->path;
			if ( $modified > $post->modified ) {
				my $updated_post = $self->get_post($post->id);
				for (qw(id published title type format author topics)) {
					$post->{$_} = $updated_post->{$_};
				}
				$post->{modified} = $modified;
				push @post_ids, $post->id;
				$dirty++;
			}
		} else {
			undef $post;
			$dirty++;
		}
	}

	# check for entries missing from the cache
	my $data_dir = opendir($cfg->data_dir);
	while ( my $id = readdir($data_dir) ) {
		unless ( first {$_ eq $id} @post_ids ) {
			my $post;
			my $new_post = $self->get_post($id);
			for (qw(id published title type format author topics)) {
				$post->{$_} = $new_post->{$_};
			}
			my $path = $miril->get_path_from_id($id);
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
		$self->tpp->writefile($self->cache_data, $new_tree) 
			or $miril->process_error("Cannot update cache file", $!);
	}

	return @posts;
}

sub save {
	my $self = shift;
	my $post = dao shift;

	my $miril = $self->miril;
	my $cfg = $miril->cfg;
	
	my $miril = $self->miril;
	my @items = $self->items;

	if ($item->old_id) {
		# this is an update

		for (@items) {
			if ($_->id eq $item->old_id) {
				$_->{id}            = $item->id;
				$_->{author}        = $item->author;
				$_->{status}        = $item->status;
				$_->{title}         = $item->title;
				$_->{topics}{topic} = $item->topics;
				last;
			}
		}
		
		# delete the old file if we have changed the id
		if ($item->old_id ne $item->id) {
			unlink($self->data_path . '/' . $item->old_id) 
				or $miril->process_error("Cannot delete old version of renamed item", $!);
		}	

	} else {
		# this is a new item
		my $new_item = dao {
			id        => $item->id,
			author    => $item->author,
			status    => $item->status,
			title     => $item->title,
			topics    => { topic => [$item->topics] },
			type      => $item->type,
		};
		
		push @items, $new_item;
	}
	
	# update the cache file
	my $new_tree = $self->tree;
	$new_tree->{xml}->{item} = \@items;
	$self->{tree} = $new_tree;
	$self->tpp->writefile($self->xml_file, $new_tree) 
		or $miril->process_error("Cannot update cache file", $!, 'fatal');
	
	# update the data file
	my $content;

	$content .= "$_: " . $post->{$_} . "\n"  for qw(published title type format author);
	$content .= "topics: " . join(" ", $post->topics) . "\n";
	$content .= "<!-- END META -->\n";
	$content .= $post->text;

	my $fh = IO::File->new( File::Spec->catfile($self->data_path, $item->id), "w")
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->print($content)
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->close;
}

sub parse_meta {
	my $meta = shift;
	my @lines = split /\n/, $meta;
	my %meta;
	
	foreach my $line (@lines) {
		if ($line =~ /^(published|title|type|format|author):\s+(.+)/) {
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

	return %meta;
}
