package Miril::Publisher;

use warnings;
use strict;

use Mouse;

use Try::Tiny               qw(try catch);
use Carp                    qw();
use Ref::List               qw(list);
use Path::Class             qw(file);
use File::Path              qw();
use File::Slurp             qw();
use Text::Sprintf::Named    qw();
use Syntax::Keyword::Gather qw(gather take);
use Data::Page              qw();
use Class::Load             qw();
use Data::Dumper::Concise   qw(Dumper);
use List::Util              qw(first);
use Miril::List;

our $VERSION = '0.007';

has 'posts' => 
(
	is      => 'ro',
	isa     => 'ArrayRef[Miril::Post]',
	default => sub { [] },
	traits  => ['Array'],
	handles => { 
        get_posts     => 'elements',
        prepare_posts => 'elements',
    },
);

has 'lists' => 
(
	is      => 'ro',
	isa     => 'ArrayRef[Miril::List::Spec]',
	default => sub { [] },
	traits  => ['Array'],
	handles => { get_lists => 'elements' },
);

has 'template' => 
(
	is       => 'ro',
	isa      => 'Object',
	required => 1,
);

has 'groups' =>
(
	is      => 'ro',
	isa     => 'ArrayRef[Miril::Group]',
	traits  => ['Array'],
	handles => { get_groups => 'elements' },
);

has 'output_path' =>
(
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	coerce   => 1,
	required => 1,
);

sub prepare_lists
{
	my $self = shift;

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
					$list_definition->name,
					$list_definition->id,
					$formatter,
					$list_definition->page,
                    $list_definition->template,
				);

				take @new_lists;

				if ($list_definition->has_map)
				{
					take ( Miril::List->new(
						lists    => \@new_lists,
						path     => file($list_definition->map_location),
						title    => $list_definition->map_name,
                        template => $list_definition->map_template,
						id       => $list_definition->id,
					) );
				}
			}
			elsif ($list_definition->is_paged)
			{
				take $self->page_posts(
					$posts,
					$list_definition->page,
					$list_definition->name,
					$list_definition->id,
					$formatter,
					{},
				);
			}
			else
			{
				take ( Miril::List->new(
					posts    => $list_definition->posts,
					path     => file($list_definition->location),
					title    => $list_definition->name,
					id       => $list_definition->id,
                    template => $list_definition->template,
				) );
			}
		}
	}
}

sub group_posts
{
    my ($self, $posts, $group, $title, $id, $formatter, $page, $template) = @_;

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
                    $template,
				);
			}
			else
			{
				take ( Miril::List->new(
					posts    => \@grouped_posts,
					key      => $keys{$key},
					group    => $group->name,
					path     => file( $formatter->format({ args => $keys{$key} }) ),
					title    => $title,
					id       => $id,
                    template => $template,
				) );	
			}
		}
	};
}

sub page_posts
{
    my ($self, $posts, $entries_per_page, $title, $id, $formatter, $formatter_args, $template) = @_;

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

			take ( Miril::List->new(
				posts    => \@current_posts,
				pager    => $current_pager,
				title    => $title,
				id       => $id,
				path     => file( $formatter->format({ args => $formatter_args }) ),
                template => $template,
			) );
		}
	};
}

sub render
{
	my ( $self, $item ) = @_;

	my %params;

	if ( $item->isa('Miril::Post') )
	{
		$params{post} = $item;
	}
	elsif ( $item->isa('Miril::List') )
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
    my ($self, $filename, $data) = @_;

	$filename = file( $self->output_path, $filename ) unless $filename->is_absolute;
	my $path = $filename->dir->stringify;
	File::Path::make_path($path) or die $! unless -e $path;
	File::Slurp::write_file($filename->stringify, $data) or die $!;
}

sub publish
{
	my $self = shift;

	foreach my $item ($self->prepare_posts, $self->prepare_lists)
	{
		$self->write($item->path, $self->render($item))
	}
}

no Mouse;

1;


