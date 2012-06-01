package Miril::App::Cmd::Command::fatpack;

# ABSTRACT: Bundle Miril web UI into a single file

use strict;
use warnings;

use Miril::App::Cmd -command;

use Module::Find             ();
use Perl::PrereqScanner      ();
use CPAN::Meta::Requirements ();
use Module::Util             ();
use App::FatPacker           ();
use Path::Class              ();
use File::Temp               ();
use Capture::Tiny            ();
use File::chdir;

sub opt_spec
{
	return (
		[ 'source|s=s',  "path to miril source", ],
		[ 'version|v=s', "perl version in target environment", { default => '5.008003' } ],
	);
}

sub execute
{
	my ($self, $opt, $args) = @_;

    # find all modules in the Miril:: namespace
    my @all_modules = Module::Find::findallmod('Miril');

    # findallmod will not include Miril itself, add it
    unshift @all_modules, 'Miril';
    
    # find all Miril::App:: modules (Miril::App::PSGI and Miril::App::Cmd)
    my @app_modules = Module::Find::findallmod('Miril::App');

    # we don't need the app modules for the cgi script
    my @cgi_modules = Array::Utils::array_minus(@all_modules, @app_modules);

    # convert module names to paths
    my @miril_module_paths = map { 
        Module::Util::find_installed($_) 
    } @cgi_modules;

    # collect the prerequisites of the modules
    my $requirements = CPAN::Meta::Requirements->new;
    
    foreach my $file ( @miril_module_paths ) 
    {
        $requirements->add_requirements(
            Perl::PrereqScanner->new->scan_file($file)
        );
    }

    my @prerequisites = 
        grep { $_ !~ /^Miril\b/ }
        sort keys %{ $requirements->as_string_hash };

    # remove standard perl modules
	my $target_perl_version = '5.008003';

	my $core_modules = Module::CoreList->find_version($target_perl_version);
	
    my @non_core_prerequisites = grep {
        ! exists $core_modules->{$_} 
    } @prerequisites;

    # convert these to paths too
    my @prerequisites_paths = map {
        Module::Util::module_path($_)
    } @non_core_prerequisites;

    # create fatpacker packlists
    my $packer = App::FatPacker->new;
    my @packlists = $packer->packlists_containing(\@prerequisites_paths);

    # create a temporary directory to bundle the dependencies
    my $fatlib_dir = Path::Class::dir( File::Temp::tempdir, 'fatlib' );
    $packer->packlists_to_tree($fatlib_dir, \@packlists);

    my $fatpacked = do {
        my $parent = $fatlib_dir->parent;
        
        # App::FatPacker::script_command_file requires a 'lib' directory too
        Path::Class::dir( $parent, 'lib' )->mkpath;

        # App::FatPacker::script_command_file only works inside the cwd
        local $CWD = $fatlib_dir->parent->stringify;

        Capture::Tiny::capture_output {
            App::FatPacker->script_command_file
        };
    };

    print $fatpacked;
}

1;
