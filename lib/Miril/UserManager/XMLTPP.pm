package Miril::UserManager::XMLTPP;

use strict;
use warnings;

use XML::TreePP;
use Digest::MD5;
use List::Util qw(first);
use Data::AsObject qw(dao);
use Try::Tiny qw(try catch);
use Miril::Error qw(miril_warn miril_die);

sub new { 
	my $class = shift;
	my $cfg = shift;

	my $self = bless {}, $class;

	my $tpp = XML::TreePP->new();
	$tpp->set( indent => 2 );
	$tpp->set( force_array => ['user'] );
    my $tree;

	try {
		$tree = $tpp->parsefile( $cfg->users_data );
	} catch {
		miril_die("Could not parse users file", $_);
	};

	my @users = map { dao $_ } @{ $tree->{xml}->{user} };
	$self->{users} = \@users;

	$self->{tree} = $tree;
	$self->{tpp} = $tpp;
	$self->{xml_file} = $cfg->users_data;

	return $self;
}

sub verification_callback {
	my $self = shift;

	return sub {
		my ($username, $password) = @_;
		my $user = $self->get_user($username);
	
		my $encrypted = $self->encrypt($password);

		return ( 
			( $encrypted eq $user->{password} ) or ( $password eq $user->{password} )
			? $username : undef 
		);
	}
}

sub get_user {
	my $self = shift;
	my $username = shift;

	my $user = first {$_->username eq $username} $self->users;
	return $user;
}

sub set_user {
	my $self = shift;
	my $user = shift;

	my @users = $self->users;

	my $found = undef;
	
	# try update
	for (@users) {
		if ($_->username eq $user->username) {
			$_->{password} = $user->password;
			$_->{email}    = $user->email;
			$_->{name}     = $user->name;

			$found++;
			last;
		}
	}

	# try create
	if (!$found) {
		my $new_user = dao {
			username => $user->username,
			password => $user->password,
			email    => $user->email,
			name     => $user->name,
		};
		
		push @users, $new_user;
	}
	
	# update the xml file
	my $new_tree = $self->tree;
	$new_tree->{xml}->{user} = \@users;
	$self->{tree} = $new_tree;
	try {
		$self->tpp->writefile($self->xml_file, $new_tree);
	} catch {
		miril_warn($_);
	};
}

sub delete_user {
	my $self = shift;
	my $username = shift;

	my @users = $self->users;
	
	my $i = -1;
	for (@users) {
		$i++;
		last if $_->username eq $username;
	}
	
	if ($i != -1) {
		splice(@users, $i, 1);
	}

	my $new_tree = $self->tree;
	$new_tree->{xml}->{user} = \@users;
	$self->{tree} = $new_tree;
	try {
		$self->tpp->writefile($self->xml_file, $new_tree);
	} catch {
		miril_warn($_);
	};
}

sub encrypt {
	my $self = shift;
	my $password = shift;

	return $password;

	my $md5 = Digest::MD5->new;
	$md5->add($password);
	return $md5->digest; 
}

### ACCESSORS ###

sub users    { @{ shift->{users} };  }
sub tree     { shift->{tree};        }
sub tpp      { shift->{tpp};         }
sub xml_file { shift->{xml_file};    }

1;
