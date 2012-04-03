package Miril::CGI::Application::View;

# ABSTRACT: Interface to web UI templating backends

use strict;
use warnings;
use autodie;

use HTML::Template::Pluggable;
use HTML::Template::Plugin::Dot;
use Template::Declare;
use Miril::CGI::Application::Theme::Bootstrap;
require Template::Declare::Tags;

### CONSTRUCTOR ###

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}

### PUBLIC METHODS ###

sub load {
    my ( $self, $template, @params ) = @_;
    Template::Declare->init( 
        dispatch_to => ['Miril::CGI::Application::Theme::Bootstrap'] 
    );
    Template::Declare->show( $template, @params );
}

1;
