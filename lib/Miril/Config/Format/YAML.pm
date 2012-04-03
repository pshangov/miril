package Miril::Config::Format::YAML;

# ABSTRACT: YAML format support for Miril configuration files

use strict;
use warnings;

use YAML::Tiny;
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

	my $yaml = YAML::Tiny->read($filename);
	my %cfg = %{ $yaml->[0] };

	if ($cfg{topics})
	{
		my @topics = map { Miril::Topic->new(%{$_}) } list $cfg{topics};
		$cfg{topics} = \@topics;
	}

	if ($cfg{types})
	{
		my @types = map { Miril::Type->new(%{$_}) } list $cfg{types};
		$cfg{types} = \@types;
	}

	if ($cfg{lists})
	{
		my @lists = map { Miril::List::Spec->new(%{$_}) } list $cfg{lists};
		$cfg{lists} = \@lists;
	}

	### ADD BASE DIR INFO ###
	
    # FIXME
	$cfg{site_dir} = File::Spec->updir($filename);

	return $class->$orig(%cfg);
};

1;

