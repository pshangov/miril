package Miril::View::Text::Template;

use strict;
use warnings;

use base 'Miril::View::Abstract';

use Text::Template;
use File::Spec::Functions qw(catfile);
use Try::Tiny qw(try catch);
use Miril::Error qw(miril_warn miril_die);

sub load {
	my $self = shift;
	my %options = @_;

	my $tmpl;
	
	try {
		$tmpl = Text::Template->new( TYPE => 'FILE', SOURCE => catfile($self->tmpl_path, $options{name}) );
	} catch {
		miril_die($_);
	};

	return $tmpl->fill_in( HASH => $options{params} );
}

1;
