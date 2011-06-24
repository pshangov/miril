package Miril::CGI::Application::UserManager;

use strict;
use warnings;
use Mouse;
use Digest::MD5;
use Try::Tiny qw(try catch);

sub BUILDARGS
{
    return { data_file => $_[0] } if @_ == 1;
}

has 'data_file' =>
(
    is         => 'ro',
    isa        => 'Path::Class::File',
    lazy_build => 1,
);

has 'users' =>
(
    is         => 'rw',
    isa        => 'HashRef',
    lazy_build => 1,
    traits     => ['Hash'],
    handles    => 
    { 
        get_user    => 'get', 
        set_user    => 'set', 
        delete_user => 'delete',
    },
);

after [qw(set_user delete_user)] => \&write_data_file;

sub read_data_file
{

}

sub write_data_file
{

}

sub verification_callback 
{
	my $self = shift;

	return sub 
    {
		my ($username, $password) = @_;
		
        my $user = $self->get_user($username);
	
		my $encrypted = $self->encrypt($password);

		if ( 
			   ( $encrypted eq $user->{password} ) 
			or ( $password  eq $user->{password} )
		   )
        {
			return $username;
		} 
        else 
        {
			return;
		}
	};
}

sub encrypt 
{
	my ($self, $password) = @_;

	# only Digest::MD5 is available in core perl 5.8
	my $md5 = Digest::MD5->new;
	$md5->add($password);
	my $digest = $md5->b64digest; 
	return $digest;
}

1;

