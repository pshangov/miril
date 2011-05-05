use strict;
use warnings;

use Test::Most;

use Miril::Author;
use Miril::Type;
use Miril::Topic;
use Miril::Taxonomy;

my %authors = map { $_->[0] => Miril::Author->new(
	id   => $_->[0],
	name => $_->[1],
)} [ larry => 'Larry Wall' ], [ damian => 'Damian Conway'];

my @topics = map { Miril::Topic->new(
	id   => $_->[0],
	name => $_->[1],
)} [ perl => 'Perl' ], [ python => 'Python'], [ ruby => 'Ruby' ];

my %topics = map { $_->id => $_ } @topics;

my $type = Miril::Type->new(
	id       => 'news',
	name     => 'News',
	location => 'somewhere',
	template => 'some_template',
);

my $taxonomy = Miril::Taxonomy->new( 
    authors => \%authors, 
    topics  => \%topics, 
    types   => { news => $type },
);

isa_ok ($taxonomy, 'Miril::Taxonomy');


my $test_author = $taxonomy->get_author_by_id('larry');
isa_ok ($test_author, 'Miril::Author');
is ($test_author->name, 'Larry Wall', 'author' );

my $test_type = $taxonomy->get_type_by_id('news');
isa_ok ($test_type, 'Miril::Type');
is ($test_type->name, 'News', 'type' );

my $test_topic = $taxonomy->get_topic_by_id('perl');
isa_ok ($test_topic, 'Miril::Topic');
is ($test_topic->name, 'Perl', 'topic' );

my $test_topics = $taxonomy->get_topics_by_id([qw(perl python ruby)]);
cmp_deeply ( $test_topics, \@topics );

done_testing;
