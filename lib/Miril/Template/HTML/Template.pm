package Miril::Template::HTML::Template;

use strict;
use warnings;
use autodie;

use base 'Miril::Template::Abstract';

use HTML::Template::Pluggable;
use HTML::Template::Plugin::Dot;
use File::Spec::Functions qw(catfile);
use Try::Tiny qw(try catch);
use Miril::Exception;

sub load {
	my $self = shift;
	my %options = @_;
	my $tmpl;
	
	try 
	{
		$tmpl = HTML::Template::Pluggable->new( 
			filename          =>  catfile($self->tmpl_path, $options{name}), 
			path              => $self->{tmpl_path},
			die_on_bad_params => 0,
			global_vars       => 1,
			case_sensitive    => 1,
		);
	} 
	catch 
	{
		Miril::Exception->throw(
			message => "Could not open template file", 
			errorvar => $_,
		);
	};

	$tmpl->param( %{ $options{params} } );
	
	return $tmpl->output;
}

1;

