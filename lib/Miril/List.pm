package Miril::List;

use strict;
use warnings;
use Carp qw(croak);
use Ref::List::AsObject qw(list);
use List::Util qw(first);

### ACCESSORS ###

use Object::Tiny qw(
	posts
	key
	count
);

### CONSTRUCTOR ###

sub new {
	my $class = shift;
	my %params = @_;
	my $posts = $params{posts};

	my $self = bless {}, $class;
	
	$self->{posts} = $params{posts};
	$self->{count} = list $params{posts};
	$self->{key}   = $params{key};
	$self->{pager} = $params{pager};

	return $self;
}

### METHODS ###

sub group 
{
	my $self = shift;
	my $group_key = shift; 
	return $self->{group_key} unless $group_key;
	$self->{group_key} = $group_key;
	
	my ($obj_cb, $key_cb);

	# must work with perl 5.8 so 'switch' is a no-no
	$group_key eq 'topic'   && $obj_cb = sub { shift->topic }     && $key_cb = sub { shift->topic->id };
	$group_key eq 'type'    && $obj_cb = sub { shift->type }      && $key_cb = sub { shift->type->id };
	$group_key eq 'author'  && $obj_cb = sub { shift->author }    && $key_cb = sub { shift->author };
	$group_key eq 'm_year'  && $obj_cb = sub { shift->modified }  && $key_cb = sub { shift->modified->strftime('%y') };
	$group_key eq 'm_month' && $obj_cb = sub { shift->modified }  && $key_cb = sub { shift->modified->strftime('%y%m') };
	$group_key eq 'm_date'  && $obj_cb = sub { shift->modified }  && $key_cb = sub { shift->modified->strftime('%y%m%d') };
	$group_key eq 'p_year'  && $obj_cb = sub { shift->published } && $key_cb = sub { shift->published->strftime('%y') };
	$group_key eq 'p_month' && $obj_cb = sub { shift->published } && $key_cb = sub { shift->published->strftime('%y%m') };
	$group_key eq 'p_date'  && $obj_cb = sub { shift->published } && $key_cb = sub { shift->published->strftime('%y%m%d') };

	!$key_cb && croak "Invalid key '" . $group_key . "' passed to group.";

	my (%groups, @groups);
	
	$groups{$key_cb->($_)}->[-1] = $_ for list $self->posts;
	
	push @groups, Miril::List->new(
		posts => $groups{$_},
		key   => $obj_cb->($groups{$_}->[-1]),
	) for sort keys %groups;

	return @groups;
}

sub by_id
{
	my $self = shift;
	my $id = shift;

	return first { $_ eq $id } list $self->posts;
}

1;
