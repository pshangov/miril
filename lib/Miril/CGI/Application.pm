package Miril::CGI::Application;

# ABSTRACT: Web UI

use strict;
use warnings;
use autodie;

use Try::Tiny;
use Exception::Class;

use base 'CGI::Application';

use CGI::Application::Plugin::Redirect;
use CGI::Application::Plugin::Forward;
use File::Spec::Functions qw(catfile);
use Data::AsObject qw(dao);
use Data::Page;
use Miril;
use Miril::Exception;
use Miril::CGI::Application::View;
use Miril::CGI::Application::InputValidator;
use Miril::Publisher;
use File::Copy qw(copy);
use Number::Format qw(format_bytes);
use POSIX qw(strftime);
use Syntax::Keyword::Gather qw(gather take);
use URI::Query;
use Data::Page;
use Data::Page::Navigation;
use HTML::FillInForm::Lite;

### ACCESSORS ###

use Object::Tiny qw(
	view
	miril
);

### SETUP ###

sub setup {
	my $self = shift;

    $self->mode_param('action');
    $self->run_modes(
    	'list'         => 'list',
        'edit'         => 'edit',
        'create'       => 'create',
        'delete'       => 'delete',
        'display'      => 'display',
        'update'       => 'update',
		'publish'      => 'publish',
		'search'       => 'search',
	);

	$self->start_mode('list');
	$self->error_mode('error');

	$self->{miril}     = $self->param('miril');
	$self->{view}      = Miril::CGI::Application::View->new;

	$self->header_add( -type => 'text/html; set=utf-8');

}

### RUN MODES ###

sub error {
	my ($self, $e) = @_;

	my @error_stack;

	if ($e->isa('Miril::Exception')) {
		warn $e->errorvar;
	} elsif ($e->isa('autodie::exception')) {
		warn $e;
		$e = Miril::Exception->new(
			message  => "Unspecified error",
			errorvar => $e->stringify,
		);
	} else {
		warn $e;
		$e = Miril::Exception->new(
			message  => "Unspecified error",
			errorvar => $e,
		);
	}
	$self->view->{fatal} = $e;
	return $self->view->load('error', $e);
}

sub list {
	my $self = shift;
	my $q = $self->query;
	my $cfg = $self->miril->config;

    my $uri_query = URI::Query->new($q->Vars);
    $uri_query->strip_except(qw(title type status page));
    $uri_query->strip_null;

    my @posts = $self->miril->store->search($uri_query->hash);

    my ($pager, $uri_callback);

	if (@posts > $cfg->posts_per_page) 
    {
        # setup pager
        $pager = Data::Page->new;
        $pager->total_entries(scalar @posts);
        $pager->entries_per_page($cfg->posts_per_page);
        # $pager->pages_per_navigation($cfg->pages_per_navigation);
        $pager->pages_per_navigation(5);
        $pager->current_page($q->param('page'));

        $uri_callback = sub {
            my $page_no = shift;
            $uri_query->replace( action => 'list', page => $page_no );
            return '?' . $uri_query->stringify;
        };

        # get just the posts we need
		@posts = $pager->splice(\@posts);
    }

	return $self->view->load('list', \@posts, $pager, $uri_callback);
}

sub search {
	my $self = shift;
	return $self->view->load('search', $self->miril->taxonomy);
}

sub create {
	my $self = shift;
	return $self->view->load('create', $self->miril->taxonomy);
}

sub edit {
	my $self     = shift;
    my $q        = $self->query;
    my $id       = $q->param('id');
    my $taxonomy = $self->miril->taxonomy;

    # edit an existing post
    if ($id)
    {
        my $invalid = $self->param('form-not-valid');

        my %params;
        
        if ($invalid)
        {
            %params = $q->Vars;
        }
        else
        {
            my $post = $self->miril->store->get_post_by_id($id);

            %params = (
                id     => $post->id,
                title  => $post->title,
                type   => $post->type->id,
                status => $post->status,
                source => $post->source,
                map { 
                    $_, $taxonomy->field($_)->serialize_to_param($post->field($_))
                } $post->field_list,
            );
        }
        
        # default empty hashref if $invalid is undefined
        $invalid = {} unless $invalid;

        my $type = $params{'type'};
        my @fields = map { $taxonomy->field($_) } $taxonomy->type($type)->field_list;
        my $form = $self->view->load( 'edit', $taxonomy, \@fields, $invalid );
        
        return HTML::FillInForm::Lite->fill(\$form, \%params);
    }
    # create new post (forwarded from 'create')
    else
    {
        my $type = $q->param('type');
        my @fields = map { $taxonomy->field($_) } $taxonomy->type($type)->field_list;
        return $self->view->load('edit', $taxonomy, \@fields );
    }
}

sub update {
	my $self       = shift;
	my $q          = $self->query;
    my $type       = $q->param('type');
    my $taxonomy   = $self->miril->taxonomy;
    my @field_list = $taxonomy->type($type)->field_list;
    my @fields     = map { $taxonomy->field($_) } @field_list;
	my $validator  = Miril::CGI::Application::InputValidator->new;

	my $invalid = $validator->validate({
		id      => [qw(text_id required)],
		status  => [qw(text_id)],
		source  => [qw(paragraph_text)],
		title   => [qw(line_text required)],
		type    => [qw(text_id required)],
		old_id  => [qw(text_id)],
        map { $_->name => $_->validation } @fields
	}, $q->Vars);
	
	if ($invalid)
    {
		$self->param('form-not-valid' => $invalid);
        return $self->forward('edit');
	}
    else
    {
        my %post = map { $_ => ( $q->param($_) or undef) } 
            qw(id status source title type old_id), @field_list;

        $self->miril->store->save(%post);
        $self->redirect("?action=display&id=" . $post{id});
    }
}

sub delete {
	my $self = shift;

	my $id = $self->query->param('old_id');
	$self->miril->store->delete($id);

	$self->redirect("?action=list");
}

sub display {
	my $self = shift;
	
	my $id = $self->query->param('old_id') 
        ? $self->query->param('old_id') 
        : $self->query->param('id');

	my $post = $self->miril->store->get_post_by_id($id);

    $post
        ? return $self->view->load('display', $post)
        : $self->redirect(URI::Query->new(action => 'list')->stringify);	
}

sub publish {
	my $self = shift;

	my $rebuild = $self->query->param("rebuild");

	if ($self->query->param("do")) 
    {
        $self->miril->publisher->publish($rebuild);
		return $self->redirect(URI::Query->new(action => 'list')->stringify);
	} 
    else 
    {
		return $self->view->load('publish');
	}
}

1;
