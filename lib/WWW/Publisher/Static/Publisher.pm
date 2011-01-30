package WWW::Publisher::Static::Publisher;

use warnings;
use strict;

use Any::Moose;

use Try::Tiny               qw(try catch);
use Carp                    qw();
use Ref::List               qw(list);
use Path::Class             qw(file);
use File::Path              qw();
use File::Slurp             qw();
use Text::Sprintf::Named    qw();
use Syntax::Keyword::Gather qw(gather take);
use Params::Util            qw(_INSTANCE _ARRAY _HASH _POSINT _STRING);
use Data::Page              qw();
use Class::Load             qw();
use Data::Dumper::Concise   qw(Dumper);
use List::Util              qw(first);

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
	is      => 'ro',
	isa     => 'ArrayRef[WWW::Publisher::Static::Group]',
	traits  => ['Array'],
	handles => { get_groups => 'elements' },
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

	return gather
	{
		foreach my $list_definition ($self->get_lists) 
		{
			my $posts = $list_definition->posts;
			my $formatter = Text::Sprintf::Named->new({fmt => $list_definition->location});

			if ($list_definition->is_grouped)
			{
				my $group = first { $_->name eq $list_definition->group } $self->get_groups;
				my @new_lists = $self->group_posts(
					$posts,
					$group,
					$list_definition->title,
					$list_definition->id,
					$formatter,
					$list_definition->page,
				);

				take @new_lists;

				if ($list_definition->has_map)
				{
					take $self->list_class->new(
						lists => \@new_lists,
						path  => file($list_definition->map),
						title => $list_definition->title,
						id    => $list_definition->id,
					);
				}
			}
			elsif ($list_definition->is_paged)
			{
				take $self->page_posts(
					$posts,
					$list_definition->page,
					$list_definition->title,
					$list_definition->id,
					$formatter,
					{},
				);
			}
			else
			{
				take $self->list_class->new(
					posts => $list_definition->posts,
					path  => file($list_definition->location),
					title => $list_definition->title,
					id    => $list_definition->id,
				);
			}
		}
	}
}

sub group_posts
{
	my $self      = _INSTANCE(shift, __PACKAGE__);
	my $posts     = _ARRAY(shift);
	my $group     = _INSTANCE(shift, 'WWW::Publisher::Static::Group');
	my $title     = _STRING(shift);
	my $id        = _STRING(shift);
	my $formatter = _INSTANCE(shift, 'Text::Sprintf::Named');
	my $page      = _POSINT(shift);

	return unless $group and $posts;

	my (%grouped_posts, %keys);

	foreach my $post (list $posts)
	{
		my %post_keys = $group->get_keys($post);
		foreach my $sort_key (keys %post_keys)
		{
			$grouped_posts{$sort_key} = [] unless $grouped_posts{$sort_key};
			push @{$grouped_posts{$sort_key}}, $post;
			$keys{$sort_key} = $post_keys{$sort_key};
		}
	}

	return gather 
	{
		foreach my $key ( sort keys %grouped_posts )
		{
			my @grouped_posts = list $grouped_posts{$key};
			
			if ($page)
			{
				take $self->page_posts(
					\@grouped_posts,
					$page,
					$title,
					$id,
					$formatter,
					$keys{$key},
				);
			}
			else
			{
				take $self->list_class->new(
					posts => \@grouped_posts,
					key   => $keys{$key},
					group => $group->name,
					path  => file( $formatter->format({ args => $keys{$key} }) ),
					title => $title,
					id    => $id,
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
	my $title             = _STRING(shift);
	my $id                = _STRING(shift);
	my $formatter         = _INSTANCE(shift, 'Text::Sprintf::Named');
	my $formatter_args    = _HASH(shift);

	my $pager = Data::Page->new;
	my $total_entries = scalar @{$posts};
	$pager->total_entries($total_entries);
	$pager->entries_per_page($entries_per_page);
	

	return gather
	{
		foreach my $page_no ($pager->first_page .. $pager->last_page)
		{
			my $current_pager = Data::Page->new;
			$current_pager->total_entries($total_entries);
			$current_pager->entries_per_page($entries_per_page);
			$current_pager->current_page($page_no);
			my @current_posts = $pager->splice($posts);
			$formatter_args->{page} = $page_no;

			take $self->list_class->new(
				posts => \@current_posts,
				pager => $current_pager,
				title => $title,
				id    => $id,
				path  => file( $formatter->format({ args => $formatter_args }) ),
			);
		}
	};
}

sub render
{
	my $self = _INSTANCE(shift, __PACKAGE__);
	#my $item = _INSTANCE($_[0], 'WWW::Publisher::Static::Post') or 
	#           _INSTANCE($_[0], 'WWW::Publisher::Static::List');

	my $item = shift;

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
		name   => $item->template, 
		params => \%params,
	);
}

sub write
{
	my $self     = _INSTANCE(shift, __PACKAGE__);
	my $filename = _INSTANCE($_[0], 'Path::Class::File') or die "Not a filename: " . $_[0];
	my $data     = _STRING($_[1]);

	$filename = file( $self->output_path, $filename ) unless $filename->is_absolute;
	my $path = $filename->dir->stringify;
	File::Path::make_path($path) or die $! unless -e $path;
	File::Slurp::write_file($filename->stringify, $data) or die $!;
}

sub publish
{
	my $self = _INSTANCE(shift, __PACKAGE__);

	foreach my $item ($self->prepare_posts, $self->prepare_lists)
	{
		$self->write($item->path, $self->render($item))
	}
}

no Any::Moose;

1;

