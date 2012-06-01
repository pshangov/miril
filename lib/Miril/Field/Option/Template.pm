package Miril::Field::Option::Template;

# ABSTRACT: Template for rendering option fields

use strict;
use warnings;

use base 'Template::Declare';
use Template::Declare::Tags 'HTML';

template default => sub {
    my ($self, $name, $options, $multiple) = @_;

    select { 

        attr { 
            class => 'input-xlarge',
            id    => $name,
            name  => $name,
            size  => 3,
            $multiple ? multiple => 1 : (),
        }

        option { attr { value => '' } 'N/A' };

        while ( my ($value, $text) = each %$options ) {
            option { attr { value => $value } $text }
        }
    }
};

1;
