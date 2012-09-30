package Miril::CGI::Application::View;

# ABSTRACT: Interface to web UI templating backends

use strict;
use warnings;
use autodie;

use base qw(Template::Declare);
require Template::Declare::Tags;
use Miril::CGI::Application::Theme::Bootstrap;

__PACKAGE__->mk_classdata('title');
__PACKAGE__->mk_classdata('css');
__PACKAGE__->mk_classdata('js');

sub show {
    my ($class, @args) = @_;

    #$class->init( dispatch_to => ['Miril::CGI::Application::Theme::Bootstrap'] );
    #$class->SUPER::show(@args);
    #Template::Declare->init( dispatch_to => ['Miril::CGI::Application::Theme::Bootstrap'] );
    $class->dispatch_to( ['Miril::CGI::Application::Theme::Bootstrap'] );
    $class->SUPER::show(@args);
}

1;
