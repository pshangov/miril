package Miril::Config;

use strict;
use warnings;

use XML::TreePP;
use Data::AsObject qw(dao);
use File::Spec::Functions qw(catfile catdir);

sub new {
	my $class     = shift;
	my $miril_dir = shift;
	my $site      = shift;

	my $tpp = XML::TreePP->new();

	my $base_dir = catdir($miril_dir, 'sites', $site);
	my $filename = catfile($base_dir, 'cfg', 'config.xml');
	my $tree = $tpp->parsefile($filename);
	my $cfg = $tree->{'xml'};
	
	### SUPPLY DEFAULT VALUES ###
	
	$cfg->{store}          = 'File'           unless defined $cfg->{store};
	$cfg->{user_manager}   = 'XMLTPP'         unless defined $cfg->{user_manager};
	$cfg->{filter}         = 'Markdown'       unless defined $cfg->{filter};
	$cfg->{view}           = 'HTML::Template' unless defined $cfg->{view};

	$cfg->{items_per_page} = 10               unless defined $cfg->{items_per_page};

	$cfg->{cache_data}     = catfile($base_dir, 'cache', 'cache.xml' );
	$cfg->{latest_data}    = catfile($base_dir, 'cache', 'latest.xml');
	$cfg->{users_data}     = catfile($base_dir, 'cfg',   'users.xml' );

	$cfg->{tmpl_path}      = catdir($base_dir, 'tmpl');

	$cfg->{workflow}{status} = [qw(draft published)];
	$cfg->{statuses} = [qw(draft published)];

	### SIMPLIFY THE HASHREF ###
	
	$cfg->{authors} = $cfg->{authors}{author};
	$cfg->{topics}  = $cfg->{topics}{topic};
	$cfg->{types}   = $cfg->{types}{type};

	return dao $cfg;
}

1;
