package Miril::Error;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(process_error error_stack error);

sub process_error {
	my $miril = shift;
	my ($miril_msg, $perl_msg, $fatal) = @_;
	
	my @error_stack = $miril->error_stack;
	
	unshift @error_stack, { 
		miril_msg => $miril_msg,
		perl_msg  => $perl_msg,
	};

	$miril->error_stack(@error_stack);

	if ($fatal) {
		# Miril::setup must always succeed, otherwise we won't be able to
		# even show the error messages
		if ( (caller(3))[3] eq "Miril::setup" ) {
			return;
		} else {
			die( "miril_processed_error\n" );
		}
	}
}

sub error_stack {
	my $miril = shift;
	my @error_stack = @_;

	if (@error_stack) {
		 $miril->param('Miril::Error::error_stack', \@error_stack);
	} else {
		if ($miril->param('Miril::Error::error_stack')) {
			return @{ $miril->param('Miril::Error::error_stack') };
		} else {
			return;
		}
	}
}

sub error {
	my $miril = shift;
	my $err_msg = shift;
	warn $err_msg;

	unless ($err_msg =~ /miril_processed_error/) {
		$miril->process_error("Unspecified error", $err_msg);
	}

	my $tmpl = $miril->load_tmpl('error');
	return $tmpl->output;
}


1;
