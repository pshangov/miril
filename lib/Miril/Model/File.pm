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

}

sub save {
	my $post = shift;

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
