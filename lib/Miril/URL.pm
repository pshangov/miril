package Miril::URL;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(url);

sub url {
    my %params = @_;
    
    if (%params)
    {
        return '?' . join '&', 
            map { $_ => $params{$_} }
            map keys %params;
    }
    else
    {
        return '';
    }
}

1;
