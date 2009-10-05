package Miril::View::HTML::Template;

use strict;
use warnings;

use base 'Miril::View::Abstract';

use HTML::Template::Pluggable;
use HTML::Template::Plugin::Dot;
use File::Spec::Functions qw(catfile);
use Try::Tiny qw(try catch);
use Miril::Error qw(miril_warn miril_die);

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
		miril_die($_);
	};

	$tmpl->param( %{ $options{params} } );
	
	return $tmpl->output;
}

1;

