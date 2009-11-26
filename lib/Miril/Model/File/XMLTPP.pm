package Miril::Model::File::XMLTPP;

use strict;
use warnings;

use List::Util              qw(first);
use IO::File;
use File::stat; 
use XML::TreePP;
use File::Slurp             qw();
use Data::AsObject          qw(dao);
use File::Spec::Functions   qw(catfile splitdir);
use POSIX                   qw(strftime);
use Try::Tiny               qw(try catch);
use Scalar::Util            qw(reftype);
use Time::Local             qw(timelocal);
use Miril;

sub new {
	my $class = shift;
	my $miril = shift;

	my $cfg = $miril->cfg;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	$tpp->set( indent => 2 );
    my ($tree, @items);
	
	if (-e $cfg->xml_data) {
		$tree = $tpp->parsefile( $cfg->xml_data ) 
			or $miril->process_error("Could not read metadata file", $!, 'fatal');
		@items = dao @{ $tree->{xml}{item} };
	} else {
		# miril is run for the first time
		$tree = {};
	}

	my $self = bless {}, $class;
	$self->{data_path} = $cfg->data_path;
	$self->{miril} = $miril;
	
	# some posts have one topic only, make sure we still have an arrayref
	map { $_->{topics}{topic} = [$_->{topics}{topic}] unless ref $_->{topics}{topic} } @items;
	
	# FIXME
	$self->{items} = \@items;
	$self->apply_dates;
	my @sorted_items = sort { $a->{published}{epoch} < $b->{published}{epoch} } @{ $self->{items} };
	$self->{items} = \@sorted_items;

	$self->{tree} = $tree;
	$self->{tpp} = $tpp;
	$self->{xml_file} = $cfg->xml_data;

	return $self;
}

sub get_item {
	my $self  = shift;
	my $id = shift;

	my $miril = $self->miril;
	my $cfg = $miril->cfg;

	my $match = first {$_->id eq $id} $self->items;
	if ($match) {
		
		$match->{text} = File::Slurp::read_file($match->filename) 
			or $miril->process_error("Could not read data file", $!, 'fatal');

		my @split = split( '<!-- BREAK -->', $match->{text}, 2);
		$match->{teaser} = $split[0];

		# make sure topics are not empty xml elements
		my @topic_names = grep {$_} @{ $match->{topics}{topic} };
		
		# convert topic id's to topic objects
		if ( @topic_names ) {
			my %topics_lookup = map {$_ => 1} @topic_names;
			my @topics = grep { $topics_lookup{$_->{id}} } $cfg->topics;
			$match->{topics} = \@topics;
		} else {
			$match->{topics} = [];
		}
		
		# apply some more information
		warn $match->{type};
		my $current_type = first { $_->{id} eq $match->{type} } $cfg->types;
		my @dirs = splitdir($current_type->location);
		my $file_to_http_dir = join "/", @dirs;
		$match->{url} = $cfg->http_dir . "/" . $file_to_http_dir . $match->{id} . ".html";
		$match->{full_url} = $cfg->domain . $match->{url};
		$match->{domain} = $cfg->domain;

		return dao $match;

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

	return dao @matches;
}

sub save {
	my $self = shift;
	my $item = dao shift;
	
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
	
	# update the xml file
	my $new_tree = $self->tree;
	$new_tree->{xml}->{item} = \@items;
	$self->{tree} = $new_tree;
	$self->tpp->writefile($self->xml_file, $new_tree) 
		or $miril->process_error("Cannot update metadata file", $!, 'fatal');

	# update the data file
	my $fh = IO::File->new( File::Spec->catfile($self->data_path, $item->id), "w")
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->print($item->text)
		or $miril->process_error("Cannot update data file", $!, 'fatal');
	$fh->close;
}

sub delete {
	my $self = shift;
	my $id = shift;

	my $miril = $self->miril;
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
		or $miril->process_error("Cannot update metadata file after deletion", $!, 'fatal');

	unlink( File::Spec->catfile($self->data_path, $id) )
		or $miril->process_error("Cannot delete data file", $!, 'fatal');
}

sub apply_dates {
	my $self = shift;
	my @items = $self->items;

	my $tz = get_time_zone();

	map {
		my $filename = File::Spec->catfile($self->data_path . '/' . $_->{id});
		my $stat = stat($filename);
		$_->{filename} = $filename;
		
		my @mtime = localtime($stat->mtime);
		
		$_->{modified}{epoch} = $stat->mtime;
		$_->{modified}{print} = strftime("%A, %d %b %Y",          @mtime);
		$_->{modified}{num}   = strftime("%Y.%m.%d",              @mtime);
		$_->{modified}{slash} = strftime("%d/%m/%Y %H:%M",        @mtime);

		# ISO8601
 		$_->{modified}{iso}   = strftime("%Y-%m-%dT%H:%M:%S$tz",  @mtime);

		if ( $_->status eq 'published' and !$_->{published} ) {
			$_->{published}{print} = $_->{modified}{print};
			$_->{published}{num}   = $_->{modified}{num};
			$_->{published}{epoch} = $_->{modified}{epoch};
			$_->{published}{iso}   = $_->{modified}{iso};
		} elsif ( $_->status eq 'draft' and $_->{published} ) {
			delete $_->{published};
		} else {
		}
	} @items;

	$self->{items} = \@items;
}

# the ISO8601 standard requires timezone information in a [+-]\d{2}:\d{2} format;
# under linux POSIX:strftime provides this value as %z, but it is not portable
# so we have to calculate it ourselves
# credit: John W. Krahn, http://www.nntp.perl.org/group/perl.beginners/2003/01/msg39201.html
sub get_time_zone {
	my $local = time;
	my $gm = timelocal( gmtime $local );
	my $sign = qw( + + - )[ $local <=> $gm ];
	my $calc = sprintf "%s%02d:%02d", $sign, (gmtime abs( $local - $gm ))[2,1];	
	return $calc;
}

sub items         { @{ shift->{items} }; }
sub data_path     { shift->{data_path};  }
sub tree          { shift->{tree};       }
sub tpp           { shift->{tpp};        }
sub xml_file      { shift->{xml_file};   }
sub miril         { shift->{miril};      }

1;
