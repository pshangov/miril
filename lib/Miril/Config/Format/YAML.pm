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

	### ADD BASE DIR INFO ###
	
	$cfg{base_dir} = $cfg{domain} . $cfg{http_dir};
	$cfg{site_dir} = File::Spec->updir($filename);

	return $class->$orig(%cfg);
};

1;

