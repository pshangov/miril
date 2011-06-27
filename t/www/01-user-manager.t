use strict;
use warnings;

use Test::Most;
use File::Temp qw(tempfile);
use Path::Class qw(file);
use Miril::CGI::Application::UserManager;

my $salt = 'hello';

# plain text passwords

my $unencrypted = <<EoData;
guest:test:Guest
admin:123:Administrator
EoData

my ( $fh_unenc, $filename_unenc ) = tempfile;
$fh_unenc->print($unencrypted) or die $!;
$fh_unenc->close               or die $!;

my $um_unenc = Miril::CGI::Application::UserManager->new(file($filename_unenc));

isa_ok($um_unenc, 'Miril::CGI::Application::UserManager');

my $guest = $um_unenc->get_user('guest');

is_deeply( [$um_unenc->get_usernames], [qw(admin guest)], 'list of users');
is_deeply( [$guest->{password}, $guest->{name}], [qw(test Guest)], 'credentials' );

my $cb_unenc = $um_unenc->verification_callback;

ok ( $cb_unenc->('guest', 'test'), 'password match' );
ok ( !$cb_unenc->('guest', '123'), 'password fail' );

# encrypted passwords

my $encrypted = <<EoData;
guest:pdnlVKeSec1t1wjdbmXj6A:Guest
admin:e3UNjqz+4iSrjxqSdZtAlA:Administrator
EoData

my ( $fh_enc, $filename_enc ) = tempfile;
$fh_enc->print($encrypted) or die $!;
$fh_enc->close             or die $!;

my $um_enc = Miril::CGI::Application::UserManager->new(
    data_file => file($filename_enc),
);

isa_ok($um_enc, 'Miril::CGI::Application::UserManager');

is ( $um_enc->encrypt('kaboom'), 'pdnlVKeSec1t1wjdbmXj6A', 'encryption' );

my $cb_enc = $um_enc->verification_callback;

ok ( $cb_enc->('admin', 'bang'), 'encrypted password match' );
ok ( !$cb_enc->('admin', 'kaboom'), 'encrypted password fail' );

my $um_write = Miril::CGI::Application::UserManager->new(
    data_file => file($filename_enc),
    users     => { admin => { name => 'Administrator', password => '123'} },
);

$um_write->write_data_file;

is (file($filename_enc)->slurp, 'admin:123:Administrator', 'write data file');

my $new_admin = $um_write->get_user('admin');
$new_admin->{password} = '456';
$um_write->set_user('admin', $new_admin);

is (file($filename_enc)->slurp, 'admin:456:Administrator', 'change password');

done_testing;
