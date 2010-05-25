package Miril::Publisher;

use warnings;
use strict;

use autodie;
use Try::Tiny;
use Exception::Class;
use Carp;
use Module::Load;
use Miril::Warning;
use Miril::Exception;
use Miril::Config;
use Miril::List;
use Ref::List::AsObject qw(list);
use File::Spec::Functions qw(catfile);
use Text::Sprintf::Named;

our $VERSION = '0.007';

sub publish {
	my ($class, $miril, $rebuild) = @_;

	my $cfg = $miril->cfg;

	my (@to_create, @to_update);

	my @posts = $miril->store->get_posts;

	foreach my $post (@posts) 
	{
		if (-x $post->out_path) {
			# TODO - check if this is correct!
			if ( $rebuild or ($post->modified->epoch > -M $post->out_path) ) {
				push @to_update, $post->id;
			}
		} else {
			push @to_create, $post->id;
		}
	}

	for (@to_create, @to_update) {
		my $post = $miril->store->get_post($_);
		
		$post->{body} = $miril->filter->to_xhtml($post->body);
		$post->{teaser} = $miril->filter->to_xhtml($post->teaser);

		my $output = $miril->tmpl->load(
			name => $post->type->template, 
			params => {
				post => $post,
				cfg => $cfg,
		});

		_file_write($post->out_path, $output);
	}

	foreach my $list (list $cfg->lists) 
	{
		my @posts;

		# accept ids
		if ( $list->match->id )
		{
			push @posts, $miril->store->get_post($_) for list $list->match->id;
		}
		else 
		{
			my @params = qw(
				author
				type
				status
				topic
				created_before
				created_on
				created_after
				updated_before
				updated_on
				updated_after
				published_before
				published_on
				published_after
				last
			);
		
			my %params;

			foreach my $param (@params) {
				if ( exists $list->match->{$param} ) {
					$params{$param} = $list->match->{$param};
				}
			}

			@posts = $miril->store->get_posts(%params);
		}


		if ($list->group) {
		
			my $list_main = Miril::List->new( posts => \@posts );
			
			foreach my $list_group ($list_main->group($list->group))
			{
				my $formatter = Text::Sprintf::Named->new({fmt => $list->location});

				my $group_key = $list_group->group;
				my $f_args;

				$f_args = { topic  => $list->key->id } if $group_key eq 'topic';
				$f_args = { type   => $list->key->id } if $group_key eq 'type';
				$f_args = { author => $list->key     } if $group_key eq 'author';
		
				$f_args = { 
					year  => $list->key->strftime('%y'), 
					month => $list->key->strftime('%m'), 
					date  => $list->key->strftime('%d'), 
				} unless $group_key;

				my $location = $formatter->format({args => $f_args});
	
				my $output = $miril->tmpl->load(
					name => $list->template,
					params => {
						list => $list_group,
						cfg => $cfg,
				});
		
				my $new_filename = catfile($cfg->output_path, $location);
				_file_write($new_filename, $output);
			}
		}
		elsif ($list->page)
		{
			my $pager = Data::Page->new;
			my $posts_no = scalar @posts;
			$pager->total_entries($posts_no);
			$pager->entries_per_page($list->page);
			foreach my $page_no ($pager->first_page .. $pager->last_page)
			{
				my $current_pager = Data::Page->new;
				$current_pager->total_entries($posts_no);
				$current_pager->entries_per_page($list->page);
				$current_pager->current_page($page_no);
				my @current_posts = $pager->splice(\@posts);
	
				my $list_page = Miril::List->new(
					posts => \@current_posts,
					pager => $current_pager,
				);
					
				my $formatter = Text::Sprintf::Named->new({fmt => $list->location});
				my $location = $formatter->format({args => { page => $page_no }});

				my $output = $miril->tmpl->load(
					name => $list->template,
					params => {
						list => $list_page,
						cfg => $cfg,
				});
		
				my $new_filename = catfile($cfg->output_path, $location);
				_file_write($new_filename, $output);
			}
		}	
		else
		{
			my $output = $miril->tmpl->load(
				name => $list->template,
				params => {
					list => Miril::List->new( posts => \@posts ),
					cfg => $cfg,
			});
		
			my $new_filename = catfile($cfg->output_path, $list->location);
			_file_write($new_filename, $output);
		}
	}
}

sub _file_write {
	my ($filename, $data) = @_;
	try {
		my $fh = IO::File->new($filename, "w");
		$fh->print($data);
		$fh->close;
	} catch {
		Miril::Exception->throw(
			errorvar => $_,
			message  => 'Could not save information',
		);
	}
}

1;



