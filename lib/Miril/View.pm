package Miril::View;

use strict;
use warnings;

use HTML::Template::Pluggable;
use HTML::Template::Plugin::Dot;

### ACCESSORS ###

use Object::Tiny qw(theme pager is_authenticated latest);

### CONSTRUCTOR ###

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}


### PUBLIC METHODS ###

sub load {
	my $self = shift;
	my $name = shift;
	my %options = @_;

	my $text = $self->theme->get($name);
	
	# get css
	my $css_text = $self->theme->get('css');
	my $css = HTML::Template::Pluggable->new( scalarref => \$css_text, die_on_bad_params => 0 );

	# get header
	my $header_text = $self->theme->get('header');
	my $header = HTML::Template::Pluggable->new( scalarref => \$header_text, die_on_bad_params => 0 );
	$header->param('authenticated', $self->is_authenticated ? 1 : 0);
	$header->param('css', $css->output);
	#my @error_stack = $self->error_stack;
	#$header->param('has_error', 1 ) if @error_stack;
	#$header->param('error', \@error_stack );

	# get sidebar
	my $sidebar_text = $self->theme->get('sidebar');
	my $sidebar = HTML::Template::Pluggable->new( scalarref => \$sidebar_text, die_on_bad_params => 0 );
	$sidebar->param('latest', $self->latest);

	# get footer
	my $footer_text = $self->theme->get('footer');
	my $footer = HTML::Template::Pluggable->new( scalarref => \$footer_text, die_on_bad_params => 0 );
	$footer->param('authenticated', $self->is_authenticated ? 1 : 0);
	$footer->param('sidebar', $sidebar->output);
	
	my $tmpl = HTML::Template::Pluggable->new( scalarref => \$text, die_on_bad_params => 0 );
	$tmpl->param('authenticated', $self->is_authenticated ? 1 : 0);
	$tmpl->param('header' => $header->output, 'footer' => $footer->output );

	if ($self->pager) {

		my $pager_text = $self->tmpl->get('pager');
		my $pager = HTML::Template::Pluggable->new( scalarref => \$pager_text, die_on_bad_params => 0 );
		$pager->param('first', $self->pager->{first});
		$pager->param('last', $self->pager->{last});
		$pager->param('previous', $self->pager->{previous});
		$pager->param('next', $self->pager->{next});

		
		$tmpl->param('pager' => $pager->output );
	}

	return $tmpl;
}

1;
