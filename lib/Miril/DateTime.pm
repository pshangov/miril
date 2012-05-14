package Miril::DateTime;

# ABSTRACT: DateTime object

use strict;
use warnings;

use Mouse;
use Time::Local  ();
use POSIX        ();
use Date::Format ();
use Carp         ();
use Class::Load  ();

use overload '0+' => \&as_epoch;

has 'year'     => ( is => 'ro' );
has 'month'    => ( is => 'ro' );
has 'day'      => ( is => 'ro' );
has 'hour'     => ( is => 'ro' );
has 'minute'   => ( is => 'ro' );
has 'second'   => ( is => 'ro' );

# 2009-11-26T16:55:34+02:00
sub _re_iso   { qr/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})([+-])(\d{2}):(\d{2})/ }

# 2009-11-26 16:55:34
sub _re_ymdhm { qr/^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d)$/  }

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
    my ($class, $string) = @_;

    if ($string =~ $class->_re_ymdhm)
    {
        return $class->from_ymdhm($string);
    }
    elsif ($string =~ $class->_re_iso)
    {
        return $class->from_iso($string);
    }
    else
    {
        Carp::croak("Cannot recognize format of datetime string $string");
    }
}

sub from_ymdhm
{
    my ($class, $string) = @_;

    unless ( $string =~ $class->_re_ymdhm ) 
    {
        Carp::croak("Invalid time format (does not match 'YYYY-MM-DD HH:MM')");
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

    unless ( $iso =~ $class->_re_iso ) 
    {
        Carp::croak("Invalid time format (does not match 'YYYY-MM-DDTHH:SS:MM+HH:MM')");
    }

    my $year  = $1;
    my $month = $2;
    my $day   = $3;
    my $hour  = $4;
    my $min   = $5;
    my $sec   = $6;
    my $sign  = $7;

    my $offset = $8*60*60 + $9*60;
    $offset = -$offset if $sign eq '-';

    my $month_raw = $month - 1;
    my $year_raw  = $year - 1900;

    my $local = time;
    my $gm = Time::Local::timelocal( gmtime $local );
    my $local_offset = $local - $gm;
    
    my $time = Time::Local::timelocal($sec, $min, $hour, $day, $month_raw, $year_raw);

    if ( $offset == $local_offset ) 
    {
        return $class->from_epoch($time);
    } 
    else 
    {
        my $abs = abs($local_offset - $offset);
        my $local_time = $local_offset > $offset ? $time + $abs : $time - $abs;
        return $class->from_epoch($local_time);
    }
}

sub from_epoch
{
    my ($class, $epoch) = @_;

    my @t = localtime $epoch;
    
    return $class->new(
        year   => $t[5] + 1900,
        month  => $t[4] + 1,
        day    => $t[3],
        hour   => $t[2],
        minute => $t[1],
        second => $t[0],
    );
}

### CONVERSION ###

sub as_iso 
{
    my $self = shift;

    # get timezone
    my $local = time;
    my $gm = Time::Local::timelocal( gmtime $local );
    my $sign = qw( + + - )[ $local <=> $gm ];
    my $tz = sprintf "%s%02d:%02d", $sign, (gmtime abs( $local - $gm ))[2,1];   

    return POSIX::strftime("%Y-%m-%dT%H:%M:%S$tz", localtime $self->as_epoch);
}

sub as_datetime 
{
    my $self = shift;

    Class::Load::load_class('DateTime');

    return DateTime->new(
        year   => $self->year,
        month  => $self->month,
        day    => $self->day,
        hour   => $self->hour,
        minute => $self->minute,
        second => $self->second,
    );
}

sub as_strftime 
{
    my ($self, $format) = @_;
    return POSIX::strftime( $format, localtime $self->as_epoch );
}

sub as_epoch 
{
    my $self = shift;

    return Time::Local::timelocal(
        $self->second,
        $self->minute,
        $self->hour,
        $self->day,
        $self->month - 1,
        $self->year - 1900,
    );
}

sub as_ymdhm
{
    my $self = shift;
    return POSIX::strftime("%Y-%m-%d %H:%M", localtime $self->as_epoch);
}

1;
