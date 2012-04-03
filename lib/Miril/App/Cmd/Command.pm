package Miril::App::Cmd::Command;

# ABSTRACT: Base class for Miril commands

use strict;
use warnings;

use Miril;
use Path::Class qw(dir);
use App::Cmd::Setup -command;
use Cwd;

sub opt_spec
{
	return ( 
        [ 'dir|d=s', "website directory"  ],
	);
}

sub validate_args
{
    my ($self, $opt, $args) = @_;

    if ($opt->{dir})
    {
        $self->app->set_global_options({ dir => $opt->{dir} });
    }
}

sub miril
{
    my $self = shift;

    if (!$self->{miril})
    {
        my $global_options = $self->app->global_options;

        my $dir = $global_options->{dir};

        if ($dir)
        {
            chdir $dir or die "Cannot change working directory to $dir: $!";
        }

        if ( glob 'miril.*' )
        {
            $self->{miril} = Miril->new;
        }
        else
        {
            die "The current directory does not appear to be a Miril site";
        }
    }

    return $self->{miril};
}

1;
