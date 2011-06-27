package Miril::CGI::Application::UserManager;

use strict;
use warnings;
use Mouse;
use Digest::MD5;
use Try::Tiny qw(try catch);

around 'BUILDARGS' => sub
{
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 1 ) 
    {
        return $class->$orig( data_file => $_[0] );
    }
    else 
    {
        return $class->$orig(@_);
    }
};

has 'data_file' =>
(
    is         => 'ro',
    isa        => 'Path::Class::File',
    lazy_build => 1,
);

has 'users' =>
(
    is       => 'rw',
    isa      => 'HashRef',
    required => 1,
    builder  => 'read_data_file',
    traits   => ['Hash'],
    handles  => 
    { 
        get_user      => 'get', 
        set_user      => 'set', 
        delete_user   => 'delete',
        get_usernames => 'keys',
    },
);

after [qw(set_user delete_user)] => \&write_data_file;

sub read_data_file
{
    my $self = shift;

    my $fh = $self->data_file->open or die $!;

    my %users;

    while ( my $line = $fh->getline )
    {
        chomp $line;

        my ($username, $password, $name) = split /:/, $line;

        $users{$username} = {
            name     => $name,
            password => $password,
        };
    }

    $fh->close or die $!;

    return \%users;
}

sub write_data_file
{
    my $self = shift;
    
    my @records;

    foreach my $username ( sort $self->get_usernames )
    {
        my $user = $self->get_user($username);
        my $record = join ':', $username, $user->{password}, $user->{name};
        push @records, $record;
    }

    my $content = join "\n", @records;
    
    my $fh = $self->data_file->open('w') or die $!;
    $fh->print($content)                 or die $!;
    $fh->close                           or die $!;
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

