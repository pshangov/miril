package Miril::List;

use strict;
use warnings;
use autodie;

use Carp qw(croak);
use Ref::List qw(list);
use List::Util qw(first);
use Miril::DateTime;

### ACCESSORS ###

use Object::Tiny qw(
	posts
	key
	count
	title
	url
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
	$self->{title} = $params{title};
	$self->{url}   = $params{url};

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

	# must be perl 5.8-compatible so we can't use switch
	if ($group_key eq 'topic')
	{
		$obj_cb = sub { shift->topic };
		$key_cb = sub { shift->topic->id };
	}
	elsif ($group_key eq 'type')
	{
		$obj_cb = sub { shift->type };
		$key_cb = sub { shift->type->id };
	}
	elsif ($group_key eq 'author')
	{
		$obj_cb = sub { shift->author };
		$key_cb = sub { shift->author };
	}
	elsif ($group_key eq 'm_year')
	{
		$obj_cb = sub { shift->modified };
		$key_cb = sub { shift->modified->strftime('%Y') };
	}
	elsif ($group_key eq 'm_month')
	{
		$obj_cb = sub { shift->modified };
		$key_cb = sub { shift->modified->strftime('%Y%m') };
	}
	elsif ($group_key eq 'm_date')
	{
		$obj_cb = sub { shift->modified };
		$key_cb = sub { shift->modified->strftime('%Y%m%d') };
	}
	elsif ($group_key eq 'p_year')
	{
		$obj_cb = sub { shift->published };
		$key_cb = sub { shift->published->strftime('%Y') };
	}
	elsif ($group_key eq 'p_month')
	{
		$obj_cb = sub { shift->published };
		$key_cb = sub { shift->published->strftime('%Y%m') };
	}
	elsif ($group_key eq 'p_date')
	{
		$obj_cb = sub { shift->published };
		$key_cb = sub { shift->published->strftime('%Y%m%d') };
	}
	else
	{
		croak "Invalid key '" . $group_key . "' passed to group.";
	}

	my (%groups, @groups);
	
	foreach my $post (list $self->posts)
	{
		my $group_hash = $key_cb->($post);
		my @group;
		@group = @{ $groups{$group_hash} } if $groups{$group_hash};
		push @group, $post;
		$groups{$group_hash} = \@group;
	}

	push @groups, Miril::List->new(
		posts => $groups{$_},
		key   => $obj_cb->($groups{$_}->[-1]),
		title => $self->title,
	) for sort keys %groups;

	return @groups;
}

sub post_by_id
{
	my $self = shift;
	my $id = shift;

	return first { $_ eq $id } list $self->posts;
}

sub timestamp
{
	return Miril::DateTime->new(time());
}



1;
