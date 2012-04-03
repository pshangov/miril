package Miril::App::Cmd::Command::view;

# ABSTRACT: Display content of an individual post

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
    my $body = "<h1>" . $post->title . "</h1>" . $post->body;
    my $text = HTML::FormatText::WithLinks::AndTables->convert($body);

    print "\n" . $text;
}

1;


