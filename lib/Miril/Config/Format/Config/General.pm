package Miril::Config::Format::Config::General;

# ABSTRACT: Config::General format support for Miril configuration files

use strict;
use warnings;

use Config::General;
use Miril::Type;
use Miril::List::Spec;
use Miril::Field::Text;
use Ref::Explicit qw(hashref);
use Path::Class   qw(file);
use Class::Load   qw(load_class);

use Mouse;
extends 'Miril::Config';

around 'BUILDARGS' => sub
{
	my ($orig, $class, $filename) = @_;

	my %cfg = Config::General->new(
		-ConfigFile => $filename,
		-AutoTrue   => 1,
		-ForceArray => 1,
	)->getall;

    if ( exists $cfg{output} and exists $cfg{output}{path} ) 
    {
        my $output_path = $cfg{output}{path};
        delete $cfg{output};
        $cfg{output_path} = $output_path;
    }

	if ($cfg{type})
	{
		my @types = map {
			if ( my $fields = delete $cfg{type}{$_}{fields} ) {
				my @fields = split /\s+/, $fields;
				$cfg{type}{$_}{fields} = \@fields;
			}
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
		my %fields = map {
            my $class = 'Miril::Field::' . delete $cfg{field}{$_}{class};
            load_class $class;
            $_ => $class->new( id => $_, %{ $cfg{field}{$_} } )
        }  keys %{ $cfg{field} };

        $cfg{fields} = \%fields;

		delete $cfg{field};
	}

    if ($cfg{plugin})
    {
        $cfg{plugins} = hashref map { $_ => $cfg{plugin}{$_} } keys %{ $cfg{plugin} };
        delete $cfg{plugin};
    }

    if ($cfg{ui})
    {
        my %ui = %{ delete $cfg{ui} };
        my @fields = grep { $ui{$_} } qw(name css js);
        @cfg{@fields} = @ui{@fields};

        foreach my $field ( grep /^(css|js)$/, @fields )
        {
            $cfg{$field} = [$cfg{$field}] unless ref $cfg{$field};
        }
    }

	### ADD BASE DIR INFO ###
	
	$cfg{site_dir} = file($filename)->dir;

	return $class->$orig(%cfg);
};

1;

