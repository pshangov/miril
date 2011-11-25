package Miril::Template::Plugin::Archive;

use strict;
use warnings;

use base 'Template::Plugin';

use Ref::Explicit qw(hashref);
use Text::Sprintf::Named;
use Miril::DateTime;

sub archive
{
    my ($self, $list, $template) = @_;
    
    return unless $list->isa('Miril::List');
    
    my $formatter = Text::Sprintf::Named->new({fmt => $template});

    my ( %collect, @years );

    $collect{$_->published->year}{sprintf('%2d', $_->published->month)}++ 
        for $list->get_posts;
    
    my %dt_args = ( day => 1, hour => 1, minute => 1 );

    foreach my $year (reverse sort keys %collect)
    {
        my @months = map { hashref 
            dt    => Miril::DateTime->new( year => $year, month => $_, %dt_args ),
            posts => $collect{$year}{$_},
            url   => $formatter->format({ args => { year => $year, month => $_ }}),
        } reverse sort keys %{ $collect{$year} };

        push @years, { 
            dt     => Miril::DateTime->new( year => $year, month => 1, %dt_args ),
            months => \@months,
        };
    }

    return { years => \@years };
}

1;
