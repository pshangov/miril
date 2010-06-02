package Miril::Config;

use strict;
use warnings;
use autodie;

use XML::TreePP;
use Data::AsObject qw(dao);
use Ref::List::AsObject qw(list);
use File::Spec::Functions qw(catfile catdir);
use Miril::Topic;
use Miril::Type;

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
	$cfg->{template}       = 'HTML::Template' unless defined $cfg->{template};

	$cfg->{posts_per_page} = 10               unless defined $cfg->{posts_per_page};

	$cfg->{cache_data}     = catfile($base_dir, 'cache', 'cache.xml' );
	$cfg->{latest_data}    = catfile($base_dir, 'cache', 'latest.xml');
	$cfg->{users_data}     = catfile($base_dir, 'cfg',   'users.xml' );

	$cfg->{data_path}      = catdir($base_dir, 'data');
	$cfg->{tmpl_path}      = catdir($base_dir, 'tmpl');

	$cfg->{workflow}{status} = [qw(draft published)];
	$cfg->{statuses} = [qw(draft published)];

	my @topics = map { 
		Miril::Topic->new(
			id   => $_->{id},
			name => $_->{name},
		) 
	} list $cfg->{topics}{topic};

	my @types = map {
		Miril::Type->new(
			id       => $_->{id},
			name     => $_->{name},
			location => $_->{location},
			template => $_->{template},
		)
	} list $cfg->{types}{type};

	my @lists = map {
		{
			id       => $_->{id},
			name     => $_->{name},
			match    => $_->{match},
			template => $_->{template},
			location => $_->{location},
			title    => $_->{title},
		}
	} list $cfg->{lists}{list};

	### SIMPLIFY THE HASHREF ###
	
	$cfg->{authors} = $cfg->{authors}{author} ? $cfg->{authors}{author} : [];
	$cfg->{topics}  = \@topics;
	$cfg->{types}   = \@types;
	$cfg->{lists}   = \@lists;

	return dao $cfg;
}

1;
