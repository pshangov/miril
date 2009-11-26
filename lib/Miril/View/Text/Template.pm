package Miril::View::Text::Template;

use strict;
use warnings;

use base 'Miril::View::Abstract';

use Text::Template;
use File::Spec::Functions qw(catfile);
use Try::Tiny qw(try catch);

sub load {
	my $self = shift;
	my %options = @_;

	my $tmpl;
	
	try {
		$tmpl = Text::Template->new( TYPE => 'FILE', SOURCE => catfile($self->tmpl_path, $options{name}) );
	} catch {
		$self->miril->process_error("Could not open template file", $_, 'fatal');
	};

	return $tmpl->fill_in( HASH => $options{params} );
}

1;
