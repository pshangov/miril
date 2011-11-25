package Miril::Template::Plugin::TagUrl;

use strict;
use warnings;

use base 'Template::Plugin';

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

1;
