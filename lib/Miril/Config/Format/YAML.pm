package Miril::Config::Format::YAML;

use strict;
use warnings;

use YAML::Tiny;
use Ref::List qw(list);
use Miril::Topic;
use Miril::Type;
use File::Spec;

use Mouse;
extends 'Miril::Config';

around 'BUILDARGS' => sub
{
	my ($orig, $class, $filename) = @_;

	$yaml = YAML::Tiny->read($filename);
	my %cfg = %{ $yaml->[0] };
	
	if ($cfg{topics})
	{
		my @topics = map { 
			Miril::Topic->new( id => $_, %{ $cfg{topic}{$_} }) 
		} keys %{ $cfg{topic} };
		$cfg{topics}  = \@topics;
		delete $cfg{topic};
	}

	if ($cfg{types})
	{
		my @types = map { 
			Miril::Type->new( id => $_, %{ $cfg{type}{$_} }) 
		} keys %{ $cfg{type} };
		$cfg{types} = \@types;
		delete $cfg{type};
	}

	if ($cfg{lists})
	{
		my @lists = map { { id => $_, %{ $cfg{list}{$_} } } }  keys %{ $cfg{list} };
		$cfg{lists} = \@lists;
		delete $cfg{list};
	}

	### ADD BASE DIR INFO ###
	
	$cfg{base_dir} = $cfg{domain} . $cfg{http_dir};
	$cfg{site_dir} = File::Spec->updir($filename);

	return $class->$orig(%cfg);
};

1;

