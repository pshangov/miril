use strict;
use warnings;

use Test::Most;

use Miril::Post;
use Miril::List;
use Miril::Type;
use Miril::DateTime;
use Miril::Template::Plugin::Miril;

my $base_url = 'example.com';
my $plugin   = Miril::Template::Plugin::Miril->new;
my $dt       = Miril::DateTime->new(
    year    => 2011, 
    month   => 11, 
    day     => 22, 
    hour    => 18, 
    minutes => 30
);

my $type = Miril::Type->new(
	id       => 'my_type',
	name     => 'My Type',
	location => 'somewhere',
	template => 'some_template',
);

my $post = Miril::Post->new(
    id        => 'my_post',
    title     => 'My Post',
    type      => $type,
    published => $dt,
);

my $list = Miril::List->new(
    id       => 'my_list',
	title    => 'My List',
	template => 'list_template',
	posts    => [$post],
);

my $tagurl_post = $plugin->tagurl($post, $base_url);
my $tagurl_list = $plugin->tagurl($list, $base_url);

is   ( $tagurl_post,  q[tag:example.com,2011-11-22:/my_post] );
like ( $tagurl_list, qr[tag:example\.com,\d{4}-\d{2}-\d{2}:/list/my_list] );

done_testing;
