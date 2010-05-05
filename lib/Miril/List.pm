package Miril::List;

use strict;
use warnings;

use Ref::List::AsObject qw(list);

### ACCESSORS ###

use Object::Tiny qw(
	posts
	name
	authors
	topics
	types
	span
	count
);

### CONSTRUCTOR ###

sub new {
	my $class = shift;
	my @posts = @_;
	
	my $self = bless {}, $class;

	my (%topics, %types, %authors);
	foreach my $post (@posts) {
		$authors{$post->author}++;
		$types{$post->type->name}++;
		$topcs{$_->name}++ for list $post->topics;
	}
	
	$self->{posts}   = \@posts;
	$self->{count}   = @posts;
	$self->{topics}  = [keys %topics];
	$self->{types}   = [keys %types];
	$self->{authors} = [keys %authors];

	return $self;
}

### METHODS ###

sub match {
	my $self = shift;
	my %conditions = @_; #author topic type span
}

1;
