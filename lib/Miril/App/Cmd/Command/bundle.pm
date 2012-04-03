package Miril::App::Cmd::Command::bundle;

# ABSTRACT: Bundle Miril web UI into a single file

use strict;
use warnings;
use autodie;

use Miril::App::Cmd -command;

use File::Find::Rule;
use File::Find::Rule::Perl;
use Module::ScanDeps;
use Module::CoreList;
use List::Util qw(first);
use List::MoreUtils qw(uniq);
use Data::Dumper;
use File::Spec;
use Syntax::Keyword::Gather;
use Array::Utils qw(array_minus);
use Regexp::Assemble;
use Module::Locate;
use Archive::Any::Create;
use File::Slurp;

sub opt_spec
{
	return (
		[ 'dir|d=s',  "miril base dir", { default => 'example' }     ],
		[ 'site|s=s', "website",        { default => 'example.com' } ],
	);
}

sub execute 
{
	my ($self, $opt, $args) = @_;
	
	# we require at least perl 5.8.3 to run Miril
	# unicode in earlier perls is considered not completely stable
	my $TARGET_VERSION = '5.008003';
	my $START_DIR = './lib';

	my $core_modules = Module::CoreList->find_version($TARGET_VERSION);

	my @skip_miril_modules = qw(
		Miril::App::Cmd
		Miril::App::Cmd::Command::publish
		Miril::App::Cmd::Command::server
		Miril::App::PSGI
	);

	my @remove_namespaces = qw(
		LWP
		HTTP
		URI
		HTML::HeadParser
		HTML::Parser
		HTML::Entities
		Mail
		File::Listing
		Compress::Bzip2
		Crypt::SSLeay
		IO::Socket::SSL
		Math::BigInt::GMP
		Digest::SHA1
		Net
		Regexp::Common
		Fatal
		IPC
		Win32::Process
		Time::Zone
	);

	# give me absolute path of all Miril modules
	my @files = map { File::Spec->rel2abs($_) } File::Find::Rule->perl_module->in($START_DIR);

	# give me abolute path of all Miril modules I need to skip
	my @skip_files = gather 
	{
		foreach my $module (@skip_miril_modules)
		{
			my @parts = split '::', $module;
			my $last_part = ( pop @parts ) . '.pm';
			my $filename = File::Spec->catfile($START_DIR, @parts, $last_part);
			take( File::Spec->rel2abs($filename) );
		}
	};

	# remove skipped modules from file list
	@files = array_minus(@files, @skip_files);

	my $deps = scan_deps(@files);

	my @names;

	foreach my $key (sort keys %$deps) 
	{
		my $mod = $deps->{$key};

		my $name = $key;
		$name =~ s!/!::!g;
		$name =~ s!.pm$!!i;
		$name =~ s!^auto::(.+)::.*!$1!;

		$deps->{$key}{name} = $name;

		my $privPath = "$Config::Config{privlibexp}/$key";
		my $archPath = "$Config::Config{archlibexp}/$key";
		$privPath =~ s|\\|\/|og;
		$archPath =~ s|\\|\/|og;
		
		next if $mod->{file} eq $privPath or $mod->{file} eq $archPath;

		push @names, $name;
	}

	# 1. filter out duplicates
	@names = uniq @names;

	# 2. remove core modules
	@names = grep { ! exists $core_modules->{$_} } @names;

	# 3. remove unwanted modules
	my $remove_re = Regexp::Assemble->new->add( map { '^' . $_ . '(::.+)?' } @remove_namespaces )->re;
	@names = grep { $_ !~ /$remove_re/ } @names;

	my %final;

	foreach my $key (sort keys %$deps)  
	{
		next if $key =~ /^auto\//;
		my $name = $deps->{$key}{name};
		if ( first { $_ eq $name } @names )
		{
			$final{$key} =  $deps->{$key};
		}
	}

	my $archive = Archive::Any::Create->new;
	$archive->container('miril');               # top-level directory

	foreach my $key (keys %final)
	{
		my $file = $final{$key}{file};
		next unless $file;
		my $data = File::Slurp::slurp($file);
		$archive->add_file('lib/' . $key, $data);	
	}

	$archive->write_file('miril.zip');
}

1;
