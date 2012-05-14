use strict;
use warnings;

use Test::Most;

use Miril::Field::Option;
use Miril::Type;
use Miril::Taxonomy;

my $type = Miril::Type->new(
	id       => 'news',
	name     => 'News',
	location => 'somewhere',
	template => 'some_template',
);

my $authors = Miril::Field::Option->new(
	id      => 'author',
	name    => 'Author',
	options => {
		larry  => 'Larry Wall',
		damian => 'Damian Conway',
	},
);

my $topics = Miril::Field::Option->new(
	id       => 'topic',
	name     => 'author',
	multiple => 1,
	options  => {
		perl   => 'Perl',
		python => 'Python',
		ruby   => 'Ruby',
	},
);

my $taxonomy = Miril::Taxonomy->new( 
    types  => { news => $type },
	fields => { author => $authors, topic => $topics },
);

isa_ok ($taxonomy, 'Miril::Taxonomy');

my $test_type = $taxonomy->type('news');
isa_ok ($test_type, 'Miril::Type');
is ($test_type->name, 'News', 'type' );

my $test_author = $taxonomy->field('author');
isa_ok ($test_author, 'Miril::Field::Option');
is ($test_author->option('larry'), 'Larry Wall', 'author' );

my $test_topic = $taxonomy->field('topic');
isa_ok ($test_topic, 'Miril::Field::Option');
is ($test_topic->option('perl'), 'Perl', 'topic' );

done_testing;
