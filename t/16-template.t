#!perl
use strict;
use warnings;

use rlib;
use Test::Most;
use Miril::Template;
use Miril::DateTime;
use Miril::Type;
use Miril::Post;
use Miril::Config::Format::Config::General;
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

my $type = Miril::Type->new(
	id       => 'news',
	name     => 'News',
	location => 'somewhere',
	template => 'some_template',
);

my $post = Miril::Post->new(
    id        => 'aenean_eu_lorem',
    title     => 'Aenean Eu Lorem',
    type      => $type,
    source    => $source,
    status    => 'published',
    published => $now,
    #fields    => { author => $author, topic => \@topics },
);

isa_ok ($post, 'Miril::Post');

# TT fails if $fh is still open
close $fh;

my $tt_output = $tt->load( 
    name   => $filename,
    params => { post => $post },
);

eq_or_diff ($tt_output, $output, 'template output');

my $config_filename = File::Spec->catfile( 
    $FindBin::Bin, 'config', 'miril.conf',
);

my $config = Miril::Config::Format::Config::General->new($config_filename);
my $options = $config->template;
    
is_deeply( 
    $options, { EVAL_PERL => 1, VARIABLES => { root => '/' } }, 
    "template options from config file" 
);

done_testing;
