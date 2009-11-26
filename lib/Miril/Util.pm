package Miril::Util;

use strict;
use warnings;

use base 'Exporter';

use List::Util qw(first);
use Data::AsObject qw(dao);
use Try::Tiny qw(try catch);
use File::Spec::Functions qw(catfile);
use XML::TreePP;
use Data::Page;
use HTML::Template::Pluggable;
use HTML::Template::Plugin::Dot;

our @EXPORT_OK = qw(
	get_target_filename
	get_last_modified_time
	get_latest
	add_to_latest
	generate_paged_url
	paginate
	load_tmpl
	prepare_authors
	prepare_statuses
	prepare_topics
	prepare_types
);

sub get_target_filename {
	my $self = shift;

	my $cfg = $self->cfg;

	my ($name, $type) = @_;

	my $current_type = first {$_->id eq $type} $cfg->types;
	my $target_filename = catfile($cfg->output_path, $current_type->location, $name . ".html");

	return $target_filename;
}

sub get_last_modified_time {
	my $self = shift;
	my $filename = shift;

	return time() - ( (-M $filename) * 60 * 60 * 24 );
}

sub get_latest {
	my $self = shift;
	
	my $cfg = $self->cfg;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	my $tree;
	my @items;
	
	try { 
		$tree = $tpp->parsefile( $cfg->latest_data );
		# force array
		@items = dao @{ $tree->{xml}{item} };
	} catch {
		$self->process_error($_);
	};
	

	return \@items;
}

sub add_to_latest {
	my $self = shift;
	my $cfg = $self->cfg;

	my ($id, $title) = @_;

    my $tpp = XML::TreePP->new();
	$tpp->set( force_array => ['item'] );
	my $tree;
	my @items;
	
	if ( -e $cfg->latest_data ) {
		try { 
			$tree = $tpp->parsefile( $cfg->latest_data );
			@items = @{ $tree->{xml}->{item} };
		} catch {
			$self->process_error($_);
		};
	}

	@items = grep { $_->{id} ne $id } @items;
	unshift @items, { id => $id, title => $title};
	@items = @items[0 .. 9] if @items > 10;

	$tree->{xml}{item} = \@items;
	
	try { 
		$tpp->writefile( $cfg->latest_data, $tree );
	} catch {
		$self->process_error("Failed to include in latest used", $_);
	};
}

sub generate_paged_url {
	my $self = shift;
	my $page_no = shift;

	my $q = $self->query;

	my $paged_url = '?action=' . $q->param('action');

	if (
		$q->param('title')  or
		$q->param('author') or
		$q->param('type')   or
		$q->param('status') or
		$q->param('topic')
	) {
		$paged_url .=   '&title='  . $q->param('title')
		              . '&author=' . $q->param('author') 
		              . '&type='   . $q->param('type') 
		              . '&status=' . $q->param('status')
		              . '&topic='  . $q->param('topic');
	}

	$paged_url .= "&page_no=$page_no";

	return $paged_url;
}

sub paginate {
	my $self = shift;
	my @items = @_;
	
	my $cfg = $self->cfg;

	return unless @items;

	if (@items > $cfg->items_per_page) {

		my $page = Data::Page->new;
		$page->total_entries(scalar @items);
		$page->entries_per_page($cfg->items_per_page);
		$page->current_page($self->query->param('page_no') ? $self->query->param('page_no') : 1);
		
		my $pager;
		
		if ($page->current_page > 1) {
			$pager->{first}    = $self->generate_paged_url($page->first_page);
			$pager->{previous} = $self->generate_paged_url($page->previous_page);
		}

		warn $page->first_page;

		if ($page->current_page < $page->last_page) {
			$pager->{'last'} = $self->generate_paged_url($page->last_page);
			$pager->{'next'} = $self->generate_paged_url($page->next_page);
		}

		$self->{pager} = $pager;
		return $page->splice(\@items);

	} else {
		return @items;
	}
}

sub load_tmpl {
	my $self = shift;
	my $name = shift;
	my %options = @_;

	my $text = $self->tmpl->get($name);
	
	# get css
	my $css_text = $self->tmpl->get('css');
	my $css = HTML::Template::Pluggable->new( scalarref => \$css_text, die_on_bad_params => 0 );

	# get header
	my $header_text = $self->tmpl->get('header');
	my $header = HTML::Template::Pluggable->new( scalarref => \$header_text, die_on_bad_params => 0 );
	$header->param('authenticated', $self->authen->is_authenticated ? 1 : 0);
	$header->param('css', $css->output);
	my @error_stack = $self->error_stack;
	$header->param('has_error', 1 ) if @error_stack;
	$header->param('error', \@error_stack );

	# get sidebar
	my $sidebar_text = $self->tmpl->get('sidebar');
	my $sidebar = HTML::Template::Pluggable->new( scalarref => \$sidebar_text, die_on_bad_params => 0 );
	$sidebar->param('latest', $self->get_latest);

	# get footer
	my $footer_text = $self->tmpl->get('footer');
	my $footer = HTML::Template::Pluggable->new( scalarref => \$footer_text, die_on_bad_params => 0 );
	$footer->param('authenticated', $self->authen->is_authenticated ? 1 : 0);
	$footer->param('sidebar', $sidebar->output);
	
	my $tmpl = HTML::Template::Pluggable->new( scalarref => \$text, die_on_bad_params => 0 );
	$tmpl->param('authenticated', $self->authen->is_authenticated ? 1 : 0);
	$tmpl->param('header' => $header->output, 'footer' => $footer->output );

	if ($self->pager) {

		my $pager_text = $self->tmpl->get('pager');
		my $pager = HTML::Template::Pluggable->new( scalarref => \$pager_text, die_on_bad_params => 0 );
		$pager->param('first', $self->pager->{first});
		$pager->param('last', $self->pager->{last});
		$pager->param('previous', $self->pager->{previous});
		$pager->param('next', $self->pager->{next});

		warn $pager->output;
		
		$tmpl->param('pager' => $pager->output );
	}

	

	return $tmpl;
}

sub prepare_authors {
	my ($self, $selected) = @_;
	my $cfg = $self->cfg;
	my @authors;
	if ($selected) {
		@authors = map +{ name => $_, id => $_ , selected => $_ eq $selected }, $cfg->authors;
	} else {
		@authors = map +{ name => $_, id => $_  }, $cfg->authors;
	}
	return \@authors;
}

sub prepare_statuses {
	my ($self, $selected) = @_;
	my $cfg = $self->cfg;
	my @statuses = map +{ name => $_, id => $_, selected => $_ eq $selected }, $cfg->statuses;
	return \@statuses;
}

sub prepare_topics {
	my ($self, %selected) = @_;
	my $cfg = $self->cfg;
	my @topics   = map +{ name => $_->name, id => $_->id, selected => $selected{$_->id} }, $cfg->topics;
	return \@topics;
}

sub prepare_types {
	my ($self, $selected) = @_;
	my $cfg = $self->cfg;
	my @types = map +{ name => $_->name, id => $_->id, selected => $_->id eq $selected }, $cfg->types;
	return \@types;
}

1;
