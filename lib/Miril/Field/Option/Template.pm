package Miril::Field::Option::Template;

# ABSTRACT: Template for rendering option fields

use strict;
use warnings;

use base 'Template::Declare';
use Template::Declare::Tags 'HTML';

template default => sub {
    my ($self, $field) = @_;

    select { 

        attr { 
            class => 'input-xlarge',
            id    => $field->id,
            name  => $field->id,
            $field->multiple ? ( multiple => 1, size => 3 ) : (),
        }

        option { attr { value => '' } 'N/A' };

        foreach my $option ( sort $field->option_list ) {
            option { attr { value => $option } $field->option($option) }
        }
    }
};

1;
