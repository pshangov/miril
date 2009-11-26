package Miril::View::HTML::Template;

use strict;
use warnings;

use base 'Miril::View::Abstract';

use HTML::Template::Pluggable;
use HTML::Template::Plugin::Dot;
use File::Spec::Functions qw(catfile);
use Try::Tiny qw(try catch);

sub load {
	my $self = shift;
	my %options = @_;
	my $tmpl;
	
	try {
		$tmpl = HTML::Template::Pluggable->new( 
			filename          =>  catfile($self->tmpl_path, $options{name}), 
			path              => $self->{tmpl_path},
			die_on_bad_params => 0,
			global_vars       => 1,
		);
	} catch {
		$self->miril->process_error("Could not open template file", $_, 'fatal');
	};

	$tmpl->param( %{ $options{params} } );
	
	return $tmpl->output;
}

1;

