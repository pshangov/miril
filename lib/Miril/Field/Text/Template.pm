package Miril::Field::Text::Template;

# ABSTRACT: Template for rendering text fields

use strict;
use warnings;

use base 'Template::Declare';
use Template::Declare::Tags 'HTML';

template default => sub {
    my ($self, $id, $value) = @_;

    input { attr {
            type  => 'text',
            class => 'input-xlarge',
            id    => $id,
            name  => $id,
        } $value
    }
};

1;
