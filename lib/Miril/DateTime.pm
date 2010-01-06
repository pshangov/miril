package Miril::DateTime;

use strict;
use warnings;

use POSIX;
use Time::Local qw(timelocal);

sub new      { bless \$_[1], $_[0] }
sub epoch    { ${$_[0]} }
sub iso      { _time2iso(${$_[0]}) }

no warnings qw(redefine);
sub strftime { POSIX::strftime($_[1], localtime(${$_[0]})) }
use warnings qw(redefine);

sub _time2iso {
	my $time = shift;

	# get timezone
	my $local = time;
	my $gm = timelocal( gmtime $local );
	my $sign = qw( + + - )[ $local <=> $gm ];
	my $tz = sprintf "%s%02d:%02d", $sign, (gmtime abs( $local - $gm ))[2,1];	

	# iso
	my @time = localtime $time;
	my $iso = POSIX::strftime("%Y-%m-%dT%H:%M:%S$tz", @time);

	return $iso;
}

1;
