package WWW::Publisher::Static::Publisher;

use warnings;
use strict;

use Any::Moose;

use Try::Tiny               qw(try catch);
use Carp                    qw();
use Ref::List               qw(list);
use Path::Class             qw();
use File::Path              qw();
use File::Slurp             qw();
use Text::Sprintf::Named    qw();
use Syntax::Keyword::Gather qw(gather take);
use Params::Util            qw(_INSTANCE _ARRAY _POSINT _STRING);
use Data::Page              qw();
use Class::Load             qw();

our $VERSION = '0.007';

has 'posts' => 
(
	is      => 'ro',
	isa     => 'ArrayRef[WWW::Publisher::Static::Post]',
	default => sub { [] },
	traits  => ['Array'],
	handles => { get_posts => 'elements' },
);

has 'lists' => 
(
	is      => 'ro',
	isa     => 'ArrayRef[WWW::Publisher::Static::List]',
	default => sub { [] },
	traits  => ['Array'],
	handles => { get_lists => 'elements' },
);

has 'template' => (
	is       => 'ro',
	isa      => 'Object',
	required => 1,
);

has 'groups' =>
(
	is  => 'ro',
	isa => 'ArrayRef[WWW::Publisher::Static::Group]',
);

has 'stash' =>
(
	is => 'ro',
);

has 'output_path' =>
(
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	coerce   => 1,
	required => 1,
);

has 'list_class' =>
(
	is       => 'ro',
	isa      => 'Str',
	required => 1,
	default  => 'WWW::Publisher::Static::List',
);

sub BUILD
{
	my $self = _INSTANCE(shift, __PACKAGE__);
	Class::Load::load_class($self->list_class);
}

sub prepare_posts
{
	my $self = _INSTANCE(shift, __PACKAGE__);
	return $self->get_posts;
}

sub prepare_lists
{
	my $self = _INSTANCE(shift, __PACKAGE__);
	my $list_class = $self->list_class;

	return gather
	{
		foreach my $list_definition ($self->get_lists) 
		{
			my $posts = $list_definition->posts;
			
			if ($list_definition->is_grouped)
			{
				my @new_lists = $self->group_posts(
					group => $list_definition->group,
					posts => $posts,
					page  => $list_definition->page,
				);

				take @new_lists;

				if ($list_definition->map)
				{
					take $list_class->new(
						lists => \@new_lists,
					);
				}
			}
			elsif ($list_definition->is_paged)
			{
				take $self->page_posts(
					$posts,
					$list_definition->page,
					$list_definition->location,
					$list_definition->title,
					$list_definition->id,
				);
			}
			else
			{
				take $list_definition;
			}
		}
	}
}

sub group_posts
{
	my $self  = _INSTANCE(shift, __PACKAGE__);
	my $group = _INSTANCE(shift, 'WWW::Publisher::Static::Group');
	my $posts = _ARRAY(shift);
	my $page  = _POSINT(shift);

	return unless $group and $posts;

	my $list_class = $self->list_class;

	my %grouped_posts;

	foreach my $post (list $posts)
	{
		foreach my $key ($group->get_keys($post))
		{
			$grouped_posts{$key} = [] unless $grouped_posts{$key};
			push @{$grouped_posts{$key}}, $post;
		}
	}

	return gather 
	{
		foreach my $key ( sort keys %grouped_posts )
		{
			my @grouped_posts = list $grouped_posts{$key};
			
			if ($page)
			{
				take $self->page_posts(@grouped_posts);
			}
			else
			{
				take $list_class->new(
					posts         => \@grouped_posts,
					key_as_hash   => $group->get_key_as_hash($grouped_posts[0]),
					key_as_object => $group->get_key_as_object($grouped_posts[0]),
					group         => $group,
				);	
			}
		}
	};
}

sub page_posts
{
	my $self              = _INSTANCE(shift, __PACKAGE__);
	my $posts             = _ARRAY(shift);
	my $entries_per_page  = _POSINT(shift);
	my $location          = _STRING(shift);
	my $title             = _STRING(shift);
	my $id                = _STRING(shift);

	my $list_class = $self->list_class;

	my $pager = Data::Page->new;
	my $total_entries = scalar @{$posts};
	$pager->total_entries($total_entries);
	$pager->entries_per_page($entries_per_page);
	my $formatter = Text::Sprintf::Named->new({fmt => $location});

	return gather
	{
		foreach my $page_no ($pager->first_page .. $pager->last_page)
		{
			my $current_pager = Data::Page->new;
			$current_pager->total_entries($total_entries);
			$current_pager->entries_per_page($entries_per_page);
			$current_pager->current_page($page_no);
			my @current_posts = $pager->splice($posts);
					
			take $list_class->new(
				posts => \@current_posts,
				pager => $current_pager,
				title => $title,
				#url   => $self->_inflate_list_url( undef, $formatter->format({args => { page => $page_no }}) ),
				id    => $id,
			);
		}
	};
}

sub render
{
	my $self = _INSTANCE(shift, __PACKAGE__);
	my $item = _INSTANCE(shift, 'WWW::Publisher::Static::Post') or 
	           _INSTANCE(shift, 'WWW::Publisher::Static::List');

	my %params = ( stash => $self->stash );

	if ( $item->isa('WWW::Publisher::Static::Post') )
	{
		$params{post} = $item;
	}
	elsif ( $item->isa('WWW::Publisher::Static::List') )
	{
		$params{list} = $item;
	}
	else
	{
		die "Unknown object passed for rendering!";
	}

	return $self->template->load(
		name => $item->template, 
		params => \%params,
	);
}

sub write
{
	my $self     = _INSTANCE(shift, __PACKAGE__);
	my $filename = _STRING(shift);
	my $data     = _STRING(shift);

	my ($volume, $directories, $file) = splitpath($filename);
	my $path = $volume . $directories;

	File::Path::make_path($path)              or die $!;
	File::Slurp::write_file($filename, $data) or die $!;
}

sub publish
{
	my $self = _INSTANCE(shift, __PACKAGE__);

	foreach my $item ($self->prepare_posts, $self->prepare_lists)
	{
		my $output = $self->render($item);
		$self->write($item->location, $output)
	}
}

no Any::Moose;

1;

