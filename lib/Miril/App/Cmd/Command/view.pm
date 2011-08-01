package Miril::App::Cmd::Command::view;

use strict;
use warnings;
use autodie;

use Miril::App::Cmd -command;
use Data::Printer;
use HTML::FormatText::WithLinks::AndTables;

sub execute 
{
	my ($self, $opt, $args) = @_;

    my $post = $self->miril->store->get_post_by_id($$args[0]);

    my $text = HTML::FormatText::WithLinks::AndTables->convert($post->body);

    #print $post->title . "\n\n";
    print $text;
}

1;


