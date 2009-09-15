package Miril::Error;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(miril_warn miril_die error_stack);

our @error_stack;
our $app;

sub miril_warn {
	my ($miril_msg, $perl_msg) = @_;
	unshift @error_stack, { 
		miril_msg => $miril_msg,
		perl_msg  => $perl_msg,
	};
}

sub miril_die {
	my ($miril_msg, $perl_msg) = @_;
	unshift @error_stack, { 
		miril_msg => $miril_msg,
		perl_msg  => $perl_msg,
	};
	if ( (caller(3))[3] eq "Miril::setup" ) {
		return;
	} else {
		die( 'miril_no_error' );
	}
}

sub error_stack {
	return @error_stack;
}

1;
