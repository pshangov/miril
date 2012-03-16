package Miril::CGI::Application;

use strict;
use warnings;
use autodie;

use Try::Tiny;
use Exception::Class;

use base 'CGI::Application';

use CGI::Application::Plugin::Redirect;
use CGI::Application::Plugin::Forward;
use Module::Load;
use File::Spec::Functions qw(catfile);
use Data::AsObject qw(dao);
use Data::Page;
use Miril;
use Miril::Exception;
use Miril::CGI::Application::Theme::Flashyweb;
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
	validator
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
	$self->{validator} = Miril::CGI::Application::InputValidator->new;

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
    $uri_query->strip_except(qw(author title type status topic page));
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
	return $self->view->load('edit', $self->miril->taxonomy);
}

sub edit {
	my $self = shift;
    my $q = $self->query;

    my %params = $self->param('form-not-valid')
        ? _query_to_params($q)
        : _post_to_params($self->miril->store->get_post_by_id($q->param('id')));

    my $form = $self->view->load('edit', $self->miril->taxonomy);
    return HTML::FillInForm::Lite->fill(\$form, \%params);
}

sub update {
	my $self = shift;
	my $q = $self->query;

	my $invalid = $self->validator->validate({
		id      => 'text_id required',
		author  => 'line_text',
		status  => 'text_id',
		source  => 'paragraph_text',
		title   => 'line_text required',
		type    => 'text_id required',
		old_id  => 'text_id',
	}, $q->Vars);
	
	if ($invalid) {
		$self->param('form-not-valid', 1);
		return $self->forward('edit');
	}

	my %post = (
		'id'     => $q->param('id'),
		'author' => ( $q->param('author') or undef ),
		'status' => ( $q->param('status') or undef ),
		'source' => ( $q->param('source') or undef ),
		'title'  => ( $q->param('title')  or undef ),
		'type'   => ( $q->param('type')   or undef ),
		'old_id' => ( $q->param('old_id') or undef ),
	);

	# SHOULD NOT BE HERE
	$post{topics} = [$q->param('topic')] if $q->param('topic');

	$self->miril->store->save(%post);

	return $self->redirect("?action=display&id=" . $post{id});
}

sub delete {
	my $self = shift;

	my $id = $self->query->param('old_id');
	$self->miril->store->delete($id);

	return $self->redirect("?action=list");
}

sub display {
	my $self = shift;
	
	my $id = $self->query->param('old_id') 
        ? $self->query->param('old_id') 
        : $self->query->param('id');

	my $post = $self->miril->store->get_post_by_id($id);

    return $post
        ? $self->view->load('display', $post)
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

### PRIVATE METHODS ###

sub _post_to_params {
    my $post = shift;

    return (
        id     => $post->id,
        title  => $post->title,
        type   => $post->type->id,
        author => $post->author,
        topics => $post->topics,
        status => $post->status,
        source => $post->source,
    );
}

sub _query_to_params {
    my $q = shift;

    return (
        id     => $q->param('id'),
        old_id => $q->param('old_id'),
        source => $q->param('source'),
        title  => $q->param('title'),
        author => $q->param('author'),
        topics => [$q->param('topics')],
        status => $q->param('status'),
        type   => $q->param('type'),
    );
}

1;
