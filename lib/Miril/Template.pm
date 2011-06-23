package Miril::Template;

use strict;
use warnings;
use Mouse;
use Template;

has 'config' =>
(
    is  => 'ro',
    isa => 'HashRef'
);

has 'tt' =>
(
    is => 'ro',
    isa => 'Template',
    lazy_build => 1,
);

sub _build_tt
{
    my $self = shift;

    my $tt = $self->config 
        ? Template->new($self->config) 
        : Template->new;
    
    return $tt;
}

sub load
{
    my ($self, %params) = @_;

    my $output;

    $self->tt->process($params{name}, $params{params}, \$output)
        or die $self->tt->error;
    
    return $output;
}

1;
