use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Miril',
    license             => 'perl',
    dist_author         => q{Peter Shangov <pshangov@yahoo.com>},
    dist_version_from   => 'lib/Miril.pm',
    build_requires => {
        'Test::More' => 0,
    },
	requires => {
		'CGI::Application'                         => 0,
		'CGI::Application::Plugin::Redirect'       => 0,
		'CGI::Application::Plugin::Forward'        => 0,
		'CGI::Application::Plugin::Authentication' => 0,
		'HTML::Template::Pluggable'                => 0,
		'HTML::Template::Plugin::Dot'              => 0,
		'IO::File'                                 => 0,
		'Cwd'                                      => 0,
		'File::Copy'                               => 0,
		'List::Util'                               => 0,
		'Scalar::Util'                             => 0,
		'Time::Format'                             => 0,
		'Number::Format'                           => 0,
		'File::Spec::Functions'                    => 0,
		'Data::AsObject'                           => 0,
		'CGI::Cookie'                              => 0,
		'Try::Tiny'                                => 0,
		'Module::Load'                             => 0,
		'Data::Page'                               => 0,
		'Text::MultiMarkdown'                      => 0,
		'Data::AsObject'                           => 0,
		'File::Slurp'                              => 0,
		'XML::TreePP'                              => 0,
		'CGI'                                      => 0,
	},
    add_to_cleanup      => [ 'Miril-*' ],
    create_makefile_pl => 'passthrough',
);

$builder->create_build_script();
