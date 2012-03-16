package Miril::Role::URL;

use strict;
use warnings;

use Mouse::Role;

requires 'path';

has 'url' =>
(
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);


sub _build_url
{
    my $self = shift;
    return $self->path->as_foreign('Unix')->stringify;
}

1;
