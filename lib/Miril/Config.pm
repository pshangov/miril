package Miril::Config;

use strict;
use warnings;

use XML::TreePP;
use Data::AsObject qw(dao);

sub new {
	my $class    = shift;
	my $filename = shift;

	my $tpp = XML::TreePP->new();
	my $tree = $tpp->parsefile($filename);
	my $cfg = $tree->{'xml'};
	
	### SUPPLY DEFAULT VALUES ###
	
	$cfg->{model}          = 'File::XMLTPP' unless defined $cfg->{model};
	$cfg->{user_manager}   = 'XMLTPP'       unless defined $cfg->{user_manager};
	$cfg->{filter}         = 'Markdown'     unless defined $cfg->{filter};

	$cfg->{items_per_page} = 10             unless defined $cfg->{items_per_page};


	return dao $cfg;
}

1;
