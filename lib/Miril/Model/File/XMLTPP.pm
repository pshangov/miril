package Miril::Model::File::XMLTPP;

use strict;
use warnings;

use List::Util qw(first);
use IO::File;
use File::stat; 
use XML::TreePP;
use File::Slurp qw();
use Data::AsObject qw(dao);
use File::Spec::Functions qw(catfile splitdir);
use POSIX qw(strftime);
use Try::Tiny qw(try catch);
use Miril::Error qw(miril_warn miril_die);
use Scalar::Util qw(reftype);

sub new {
	my $class = shift;
	my $cfg = shift;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	$tpp->set( indent => 2 );
    my ($tree, @items);
	
	if (-e $cfg->xml_data) {
		$tree = $tpp->parsefile( $cfg->xml_data ) or miril_die($!);
		@items = map { dao $_ } @{ $tree->{xml}{item} };
	} else {
		$tree = {};
	}

	my $self = bless {}, $class;
	$self->{data_path} = $cfg->data_path;
	map { $_->{topics}{topic} = [$_->{topics}{topic}] unless ref $_->{topics}{topic} } @items;
	$self->{items} = \@items;
	$self->apply_dates;
	

	my @sorted_items = sort { $a->{published}{epoch} < $b->{published}{epoch} } @{ $self->{items} };
	$self->{items} = \@sorted_items;

	$self->{tree} = $tree;
	$self->{tpp} = $tpp;
	$self->{xml_file} = $cfg->xml_data;

	$self->{topics} = $cfg->{topics}{topic};
	$self->{cfg} = $cfg;

	return $self;
}

sub get_item {
	my $self  = shift;
	my $id = shift;

	my $match = first {$_->id eq $id} $self->items;
	if ($match) {
		
		$match->{text} = File::Slurp::read_file($match->filename) or miril_die($!);

		my @split = split( '<!-- BREAK -->', $match->{text}, 2);
		$match->{teaser} = $split[0];

		if (reftype $match->{topics}{topic} eq "ARRAY") {
			my %topics = map {$_ => 1} @{ $match->{topics}{topic} };
		
			my @topics = grep { $topics{$_->{id}} } $self->topics;
			$match->{topics} = \@topics;
		} else {
			$match->{topics} = [$match->{topics}{topic}];
		}
		
		
		my $current_type = first { $_->{id} eq $match->{type} } $self->cfg->types->type;
		my @dirs = splitdir($current_type->location);
		my $file_to_http_dir = join "/", @dirs;
		$match->{url} = $self->cfg->http_dir . "/" . $file_to_http_dir . $match->{id} . ".html";
		$match->{full_url} = $self->cfg->domain . $match->{url};
		$match->{domain} = $self->cfg->domain;

		my $item = dao $match;
		return $item;

	} else {
		return;
	}
}

sub get_items {
	my $self  = shift;
	my %params = @_;

	my @matches = grep {
		($params{'title'}            ? $_->title     =~ /$params{'title'}/i         : 1) and
		($params{'author'}           ? $_->author    eq $params{'author'}           : 1) and
		($params{'type'}             ? $_->type      eq $params{'type'}             : 1) and
		($params{'status'}           ? $_->status    eq $params{'status'}           : 1)
	} $self->items;

	if ($params{'topic'}) {
		foreach my $match (@matches) {
			my %topics = map {$_ => 1} $match->topics->topic;
			undef $match unless $topics{ $params{'topic'} };
		}
	}

	return map { dao $_ } @matches;
}

sub save {
	my $self = shift;
	my $item = dao shift;

	my @items = $self->items;

	if ($item->o_id) {
		# this is an update

		for (@items) {
		
			if ($_->id eq $item->o_id) {
				$_->{id}        = $item->id;
				$_->{author}    = $item->author;
				$_->{status}    = $item->status;
				$_->{title}     = $item->title;
				$_->{topics}    = $item->topics;
				last;
			}
		}
		
		# delete the old file if we have changed the id
		if ($item->o_id ne $item->id) {
			unlink($self->data_path . '/' . $item->o_id) 
				or miril_warn("Cannot delete old version of renamed item", $!);
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
	
	# update the xml file
	my $new_tree = $self->tree;
	$new_tree->{xml}->{item} = \@items;
	require Data::Dumper;
	#warn Data::Dumper::Dumper($new_tree);
	$self->{tree} = $new_tree;
	$self->tpp->writefile($self->xml_file, $new_tree) 
		or miril_die("Cannot update metadata file", $!);

	# update the data file
	my $fh = IO::File->new( File::Spec->catfile($self->data_path, $item->id), "w")
		or miril_die("Cannot update data file", $!);
	$fh->print($item->text)
		or miril_die("Cannot update data file", $!);;
	$fh->close;
}

sub delete {
	my $self = shift;
	my $id = shift;

	my @items = $self->items;
	
	my $i = -1;
	for (@items) {
		$i++;
		last if $_->id eq $id;
	}
	
	if ($i != -1) {
		splice(@items, $i, 1);
	}

	my $new_tree = $self->tree;
	$new_tree->{xml}->{item} = \@items;
	$self->{tree} = $new_tree;
	$self->tpp->writefile($self->xml_file, $new_tree) 
		or miril_die("Cannot update metadata file after deletion", $!);

	unlink( File::Spec->catfile($self->data_path, $id) )
		or miril_die("Cannot delete data file", $!);
}

sub apply_dates {
	my $self = shift;
	my @items = $self->items;

	my @mon_abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my @week_abbr = qw( Monday Tuesday Wednesday Thursday Friday Saturday Sunday );

	map {
		my $filename = File::Spec->catfile($self->data_path . '/' . $_->{id});
		my $stat = stat($filename);
		$_->{filename} = $filename;
		
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($stat->mtime);
		$_->{modified}->{epoch} = $stat->mtime;
		$_->{modified}->{'print'} = $week_abbr[$wday-1] . ", $mday " . $mon_abbr[$mon] . " " . ($year+1900);
		$_->{modified}->{num} = sprintf("%d.%02d.%02d", $year+1900, $mon+1, $mday);
		$_->{modified}->{slash} = sprintf("%d/%02d/%02d %02d:%02d", $year+1900, $mon+1, $mday, $hour, $min);

		# ISO8601
		my $tz = strftime("%z", localtime($stat->mtime));
		$tz =~ s/(\d{2})(\d{2})/$1:$2/;
 		$_->{modified}->{iso} = strftime("%Y-%m-%dT%H:%M:%S", localtime($stat->mtime)) . $tz;	

		if ( $_->status eq 'published' and !$_->{published} ) {
			$_->{published}->{'print'} = $_->{modified}->{'print'};
			$_->{published}->{num}     = $_->{modified}->{num};
			$_->{published}->{epoch}   = $_->{modified}->{epoch};
			$_->{published}->{iso}     = $_->{modified}->{iso};
		} elsif ( $_->status eq 'draft' and $_->{published} ) {
			delete $_->{published};
		} else {
		}
	} @items;

	$self->{items} = \@items;
}

sub items         { @{ shift->{items} };    }
sub topics        { $_[0]->{topics} ? @{ shift->{topics} } : undef;   }
sub data_path     { shift->{data_path}; }
sub tree          { shift->{tree};          }
sub tpp           { shift->{tpp};           }
sub cfg           { shift->{cfg};           }
sub xml_file      { shift->{xml_file};      }

1;
