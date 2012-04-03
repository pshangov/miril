package Miril::App::Cmd::Command::test;

# ABSTRACT: Check that Miril can be loaded and exit

use strict;
use warnings;

use Miril::App::Cmd -command;
use Cwd;

sub execute 
{
	my ($self, $opt, $args) = @_;
    
    my $version = $Miril::VERSION;
    my $cwd = getcwd;
    my $config = $self->miril->config_filename;

	print 
<<EoPrint;
Hi, this is Miril version $version
Using configuration file '$config' from working directory $cwd
EoPrint

}

1;


