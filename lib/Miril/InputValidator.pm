package Miril::InputValidator;

use strict;
use warnings;

### ACCESSORS ###

use Object::Tiny qw(validator_rx);

### CONSTRUCTOR ###

sub new {
	my $class = shift;
	my $self = bless {}, $class;

	$self=>{validator_rx} = {
		line_text 		=> qr/.*/,
		paragraph_text 	=> qr/.*/m,
		text_id 		=> qr/\w{1,256}/,
		datetime 		=> qr/.*/,
		integer 		=> qr/\d{1,8}/,
	}

	return $self;
}

### PUBLIC METHODS ###

sub validate {
	my ($self, $schema, %data) = @_;
	my %invalid_fields;

	foreach my $key (keys %$schema) {
		my ($type, $required) = split /\s/, $schema->{$key};
		die "Unknown option '$required'" if $required and $required !~ /^(required)|(optional)$/;

		if ( $data{$key} ) {
			push @items_to_check, ref $data{$key} ? @{ $data{$key} } : $data{$key};
			foreach my $item_to_check (@items_to_check) {
				$invalid_fields{$key}++ unless $self->_validate_type($type, $data{$key});
			}
		} else {
			die "Required parameter '$key' missing" if $required eq 'required';
		}

		return keys %invalid_fields;
	}
}

### PRIVATE METHODS ###

sub _validate_type {
	my ($self, $type, $string) = @_;
	die "Illegal datatype $type" unless $self->validator_rx->{$type};
	return unless $string =~ $self->validator_rx->{$type};
}

1;
