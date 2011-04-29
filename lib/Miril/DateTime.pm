package Miril::DateTime;

use strict;
use warnings;

use Mouse;
use Try::Tiny;
use Time::Local  ();
use Date::Format ();
use Carp         ();

use overload '0+' => \&as_epoch;

has 'year'     => ( is => 'ro' );
has 'month'    => ( is => 'ro' );
has 'day'      => ( is => 'ro' );
has 'hour'     => ( is => 'ro' );
has 'minute'   => ( is => 'ro' );
has 'second'   => ( is => 'ro' );
has 'timezone' => ( is => 'ro' );

### CONSTRUCTORS ###

sub now
{
	my $class = shift;

	my @t = localtime time;
	
	return $class->new(
		year   => $t[5] + 1900,
		month  => $t[4] + 1,
		day    => $t[3],
		hour   => $t[2],
		minute => $t[1],
		second => $t[0],
	);
}

sub from_string
{
	my ($class, $string, $format_type) = @_;

    $format_type = 'default' unless $format_type;

	if ($format_type eq 'default')
	{
		return $class->from_ymdhm($string);
	}
	elsif ($format_type eq 'iso')
	{
		return $class->from_iso($string);
	}
	else
	{
		Carp::croak("Ivalid format type $format_type supplied to from_string");
	}
}

sub from_ymdhm
{
	my ($class, $string) = @_;

	unless ( $string =~ /^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d)$/ ) 
	{
		Carp::croak("Invalid time format (does not match 'YYYY:MM:DD HH:MM')");
	}
	
	return $class->new(
		year   => $1 + 0,
		month  => $2 + 0,
		day    => $3 + 0,
		hour   => $4 + 0,
		minute => $5 + 0,
		second => 0,
	);
}

sub from_iso
{
	my ($class, $iso) = @_;

	# 2009-11-26T16:55:34+02:00
	my $re = qr/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})([+-])(\d{2}):(\d{2})/;

	if ( $iso =~ $re ) {
		my $year = $1;
		my $month = $2 - 1;
		my $day = $3;
		my $hour = $4;
		my $min = $5;
		my $sec = $6;
		my $sign = $7;
		my $offset = $8*60*60 + $9*60;
		$offset = -$offset if $sign eq '-';

		my $local = time;
		my $gm = Time::Local::timelocal( gmtime $local );
		my $local_offset = $local - $gm;
		
		my $time = Time::Local::timelocal($sec, $min, $hour, $day, $month, $year);

		if ( $offset == $local_offset ) {
			return $time;
		} else {
			my $abs = abs($local_offset - $offset);
			$local_offset > $offset ? return $time + $abs : return $time - $abs;
		}
	}
}

sub from_epoch
{

}

### CONVERSION ###

sub as_iso 
{
	my $time = shift;

	# get timezone
	my $local = time;
	my $gm = Time::Local::timelocal( gmtime $local );
	my $sign = qw( + + - )[ $local <=> $gm ];
	my $tz = sprintf "%s%02d:%02d", $sign, (gmtime abs( $local - $gm ))[2,1];	

	# iso
	my @time = localtime $time;
	my $iso = strftime("%Y-%m-%dT%H:%M:%S$tz", @time);

	return $iso;	
}

sub as_datetime {}
sub as_strftime {}
sub as_epoch {}

1;
