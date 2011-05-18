package Miril::App::Cmd::Command;

use strict;
use warnings;

use Miril;
use Path::Class qw(dir);
use App::Cmd::Setup -command;

sub miril
{
    my $self = shift;

    if (!$self->{miril})
    {
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
