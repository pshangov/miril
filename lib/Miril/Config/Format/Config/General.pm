package Miril::Config::Format::Config::General;

# ABSTRACT: Config::General format support for Miril configuration files

use strict;
use warnings;

use Config::General;
use Miril::Type;
use Miril::List::Spec;
use Path::Class qw(file);
use Class::Load qw(load_class);

use Mouse;
extends 'Miril::Config';

around 'BUILDARGS' => sub
{
	my ($orig, $class, $filename) = @_;

	my %cfg = Config::General->new(
		-ConfigFile => $filename,
		-AutoTrue   => 1,
	)->getall;

	if ($cfg{topic})
	{
		my @topics = map { 
			Miril::Topic->new( id => $_, %{ $cfg{topic}{$_} }) 
		} keys %{ $cfg{topic} };
		$cfg{topics}  = \@topics;
		delete $cfg{topic};
	}

	if ($cfg{type})
	{
		my @types = map { 
			Miril::Type->new( id => $_, %{ $cfg{type}{$_} }) 
		} keys %{ $cfg{type} };
		$cfg{types} = \@types;
		delete $cfg{type};
	}

	if ($cfg{list})
	{
		my @lists = map { 
            Miril::List::Spec->new( id => $_, %{ $cfg{list}{$_} } )
        }  keys %{ $cfg{list} };
		$cfg{lists} = \@lists;
		delete $cfg{list};
	}

	if ($cfg{field})
	{
		my @fields = map {
            my $class = 'Miril::Field::' . delete $cfg{field}{$_}{class};
            load_class $class;
            $class->new( id => $_, %{ $cfg{field}{$_} } )
        }  keys %{ $cfg{field} };
		$cfg{fields} = \@fields;
		delete $cfg{field};
	}

	### ADD BASE DIR INFO ###
	
	$cfg{site_dir} = file($filename)->dir;

	return $class->$orig(%cfg);
};

1;

