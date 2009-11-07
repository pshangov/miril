package Miril::Error;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(miril_warn miril_die error_stack process_error);

our @error_stack;
our $app;

sub miril_warn {
	my ($miril_msg, $perl_msg) = @_;
	process_error($miril_msg, $perl_msg);
}

sub miril_die {
	my ($miril_msg, $perl_msg) = @_;
	
	process_error($miril_msg, $perl_msg);

	# Miril::setup must always succeed, otherwise we won't be able to
	# even show the error messages
	if ( (caller(3))[3] eq "Miril::setup" ) {
		return;
	} else {
		die( "miril_processed_error\n" );
	}
}

sub error_stack {
	return @error_stack;
}

sub process_error {
	my ($miril_msg, $perl_msg) = @_;
	unshift @error_stack, { 
		miril_msg => $miril_msg,
		perl_msg  => $perl_msg,
	};

	warn "Processing eror message: MIRIL says '$miril_msg', PERL says '$perl_msg'."
}

1;
