use strict;
use warnings;

use Test::Most;
use Miril::List;
use Miril::Post;
use Miril::Type;
use Miril::Template::Plugin::Miril;

my $type = Miril::Type->new( 
    id       => 'type', 
    name     => 'Type',  
    location => 'type', 
    template => 'type.tmpl'
);

my @dts = (
    '2011-11-21 12:30',
    '2011-11-12 12:30',
    '2011-10-26 12:30',
    '2011-02-21 12:30',
    '2011-02-19 12:30',
    '2011-02-09 12:30',
    '2010-03-23 12:30',
    '2009-06-11 12:30',
    '2009-05-17 12:30',
    '2009-05-02 12:30',
);

my @posts;
my $chr = 97; # lower-case 'a'

foreach my $dt (@dts)
{
    push @posts, Miril::Post->new(
		id        => $chr,
		title     => $chr,
		type      => $type,
        published => Miril::DateTime->from_ymdhm($dt),
	);
    $chr++;
}

my $list = Miril::List->new(
    id       => 'archive',
	title    => 'Archive',
	template => 'archive.tt',
	posts    => \@posts,
	location => 'archive.html',
);

my $plugin = Miril::Template::Plugin::Miril->new;

isa_ok ($plugin, 'Miril::Template::Plugin::Miril');

my $tree = $plugin->archive($list, 'archive/%(year)d/%(month)02d.html');

my @got;

foreach my $year ( @{$tree->{years}} )
{
    my @values = map { [ 
        sprintf ('%4d-%02d', $_->{dt}->year, $_->{dt}->month), 
        $_->{posts}, $_->{url} 
    ] } @{$year->{months}};

    push @got, @values;
}

my @expected = (
    [ "2011-11",  2, "archive/2011/11.html" ],
    [ "2011-10",  1, "archive/2011/10.html" ],
    [ "2011-02",  3, "archive/2011/02.html" ],
    [ "2010-03",  1, "archive/2010/03.html" ],
    [ "2009-06",  1, "archive/2009/06.html" ],
    [ "2009-05",  2, "archive/2009/05.html" ],
);

is_deeply \@got, \@expected, 'Posts ordered correctly';

done_testing;
