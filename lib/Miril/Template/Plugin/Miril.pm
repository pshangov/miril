package Miril::Template::Plugin::Miril;

# ABSTRACT: Template Toolkit plugin with Miril-related utility functions

use strict;
use warnings;

use base 'Template::Plugin';

use Ref::Explicit qw(hashref);
use Text::Sprintf::Named;
use Miril::DateTime;

# tag:www.mechanicalrevolution.com,2011-05-02:/parameter_apocalypse_take_two
sub tagurl
{
    my ($self, $item, $base_url) = @_;

    $base_url =~ s/^https?:\/\///;
    $base_url =~ s/\/$//;
    
    my ($template, $dt);

    if ($item->isa('Miril::Post'))
    {
        $template = 'tag:%s,%s:/%s';
        $dt = $item->published;
    }
    else
    {
        $template = 'tag:%s,%s:/list/%s';
        $dt = Miril::DateTime->now;
    }

    
    my $tag_url = sprintf($template, 
        $base_url,
        $dt->as_strftime('%Y-%m-%d'),
        $item->id,
    );
       
    return $tag_url;
}

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

