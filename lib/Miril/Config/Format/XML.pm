package Miril::Config::Format::XML;

use strict;
use warnings;

use XML::TreePP;
use Ref::List qw(list);
use Miril::Topic;
use Miril::Type;
use Miril::List::Spec;
use File::Spec;

use Mouse;
extends 'Miril::Config';

around 'BUILDARGS' => sub
{
	my ($orig, $class, $filename) = @_;

	my $tpp = XML::TreePP->new();
	my $tree = $tpp->parsefile($filename);
	my $cfg = $tree->{'xml'};
	
	my %args;

	my @options = qw(
		store
		user_manager
		filter
		template
		posts_per_page
		sort
		output_path
	);

	foreach my $option (@options)
	{
		$args{$option} = $cfg->{$option} if defined $cfg->{$option};
	}

	my @topics = map 
	{ 
		Miril::Topic->new(
			id   => $_->{id},
			name => $_->{name},
		) 
	} list $cfg->{topics}{topic};

	my @types = map 
	{
		Miril::Type->new(
			id       => $_->{id},
			name     => $_->{name},
			location => $_->{location},
			template => $_->{template},
		)
	} list $cfg->{types}{type};

	my @lists = map 
    { 
        Miril::List::Spec->new(
            id       => $_->{id},
            name     => $_->{name},
            template => $_->{template},
            location => $_->{location},
            match    => $_->{match},
        )
    } list $cfg->{lists}{list};

	### SIMPLIFY THE HASHREF ###
	
	$args{authors} = $cfg->{authors}{author} if $cfg->{authors}{author};
	$args{lists}   = \@lists                 if @lists;
	$args{topics}  = \@topics                if @topics;
	$args{types}   = \@types                 if @types;

	### ADD BASE DIR INFO ###
	
	$args{site_dir} = File::Spec->updir($filename);

	return $class->$orig(%args);
};

1;

