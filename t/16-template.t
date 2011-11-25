#!perl
use strict;
use warnings;

use rlib;
use Test::Most;
use Miril::Template;
use Miril::DateTime;
use Miril::Author;
use Miril::Topic;
use Miril::Type;
use Miril::Post;
use Module::Load;
use File::Temp qw(tempfile);

### CONSTRUCTION ###

my $tt = Miril::Template->new( config => { ABSOLUTE => 1 } );

isa_ok ($tt, 'Miril::Template');
isa_ok ($tt->tt, 'Template');

### POST ###

# setup

my $template = <<EoTemplate;
<html>
    <head>
        <title>[% post.title %]</title>
    </head>
    <body>
[% post.body %]
    </body>
</html>
EoTemplate

my ($fh, $filename) = tempfile;
print $fh $template;

my $output = <<EoOutput;
<html>
    <head>
        <title>Aenean Eu Lorem</title>
    </head>
    <body>
<p>Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.</p>

    </body>
</html>
EoOutput

my $source = <<EoSource;
Aenean eu lorem at odio placerat fringilla.
<!-- BREAK -->
Cras faucibus velit quis dui.
EoSource


my $now = Miril::DateTime->now;

my $author = Miril::Author->new(
	id   => 'larry',
	name => 'Larry Wall',
);

my @topics = map { Miril::Topic->new(
	id   => $_->[0],
	name => $_->[1],
)} [ perl => 'Perl' ], [ python => 'Python'];

my $type = Miril::Type->new(
	id       => 'news',
	name     => 'News',
	location => 'somewhere',
	template => 'some_template',
);


my $post = Miril::Post->new(
    id        => 'aenean_eu_lorem',
    title     => 'Aenean Eu Lorem',
    author    => $author,
    topics    => \@topics,
    type      => $type,
    source    => $source,
    status    => 'published',
    published => $now,
);

isa_ok ($post, 'Miril::Post');

# TT fails if $fh is still open
close $fh;

my $tt_output = $tt->load( 
    name   => $filename,
    params => { post => $post },
);

eq_or_diff ($tt_output, $output, 'template output');

my %formats = (
	conf => 'Config::General',
	yaml => 'YAML',
	xml  => 'XML',
);

foreach my $format ( keys %formats )
{
	my $class = "Miril::Config::Format::" . $formats{$format};
	Module::Load::load($class);
	my $config_filename = File::Spec->catfile( 
		$FindBin::Bin, 'config', 'miril.' . $format,
	);

    my $config = $class->new($config_filename);
	my $template = $config->template;
    my $stash = $config->stash;
    
    is_deeply( $template, { EVAL_PERL => 1 }, "template options from $format config file" );
    is_deeply( $stash, { root => '/' }, "template stash from $format config file" );
}

done_testing;
