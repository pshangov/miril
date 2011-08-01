package Miril::App::Cmd::Command::search;

use strict;
use warnings;
use autodie;

use Miril::App::Cmd -command;

use Class::Autouse;
Class::Autouse->autouse('Miril');
use Data::Printer;
use Text::ASCIITable;

sub opt_spec
{
	return ( 
        [ 'dir|d=s', "website directory"  ],
	);
}

sub execute 
{
	my ($self, $opt, $args) = @_;
	
    my $table = Text::ASCIITable->new;
    $table->setCols('ID', 'Title', 'Modified');

    foreach my $post ($self->miril->store->get_posts)
    {
        $table->addRow($post->id, $post->title, $post->modified->as_ymdhm);
    }

    print $table;
}

1;

