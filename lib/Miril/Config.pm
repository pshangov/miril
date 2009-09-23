package Miril::Config;

use strict;
use warnings;

use XML::TreePP;
use Data::AsObject qw(dao);
use File::Spec::Functions qw(catfile);

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

	$cfg->{xml_data}       = catfile($cfg->{cache_path}, 'data.xml');
	$cfg->{latest_data}    = catfile($cfg->{cache_path}, 'latest.xml');
	$cfg->{users_data}     = catfile($cfg->{cfg_path}, 'users.xml');

	$cfg->{workflow}{status} = [qw(draft published)];

	return dao $cfg;
}

1;
