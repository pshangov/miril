package Miril::App::Cmd::Command::list;

# ABSTRACT: List posts

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

    $table->setCols('ID', 'Title', 'Published');

    foreach my $post ($self->miril->store->get_sorted_posts)
    {
        $table->addRow(
            $post->id, $post->title, 
            $post->is_published ? $post->published->as_ymdhm : 'N/A',
        );
    }

    print $table;
}

1;

