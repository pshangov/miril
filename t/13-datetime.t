use strict;
use warnings;

use Miril::DateTime;
use Test::Most;

################
# CONSTRUCTORS #
################

my @constructors;

# Miril::DateTime->new

my $dt = Miril::DateTime->new(
    year   => 2011,
    month  => 5,
    day    => 1,
    hour   => 12,
    minute => 15,
    second => 0,
);

push @constructors, {
    name         => 'new',
    object       => $dt,
    test_seconds => 1,
    expected     => 
    {
        year   => 2011,
        month  => 5,
        day    => 1,
        hour   => 12,
        minute => 15,
        second => 0,
    },
};

# Miril::DateTime->now

my @now = localtime time;

my $dt_now = Miril::DateTime->now;

push @constructors, {
    name         => 'now',
    object       => $dt_now,
    test_seconds => 0,
    expected     => 
    {
        year   => $now[5] + 1900,
        month  => $now[4] + 1,
        day    => $now[3],
        hour   => $now[2],
        minute => $now[1],
    },
};

# Miril::DateTime->from_ymdhm

my $dt_ymdhm = Miril::DateTime->from_ymdhm('2011-05-01 12:15');

push @constructors, {
    name         => 'ymdhm',
    object       => $dt_ymdhm,
    test_seconds => 0,
    expected     => 
    {
        year   => 2011,
        month  => 5,
        day    => 1,
        hour   => 12,
        minute => 15,
    },
};

# Miril::DateTime->from_iso

my $dt_iso = Miril::DateTime->from_iso('2011-05-01T12:15:00+03:00');

push @constructors, {
    name         => 'iso',
    object       => $dt_iso,
    test_seconds => 1,
    expected     => 
    {
        year   => 2011,
        month  => 5,
        day    => 1,
        hour   => 12,
        minute => 15,
        second => 0,
    },
};

# this test will produce different results depending on timezone in which it is run
# disable until I figure out a good way to deal with this
pop @constructors;

# Miril::DateTime->from_epoch

my $dt_epoch = Miril::DateTime->from_epoch(1304241300);

push @constructors, {
    name         => 'epoch',
    object       => $dt_epoch,
    test_seconds => 1,
    expected     => 
    {
        year   => 2011,
        month  => 5,
        day    => 1,
        hour   => 12,
        minute => 15,
        second => 0,
    },
};

foreach my $constructor (@constructors)
{
    my ($name, $object, $test_seconds) = @$constructor{qw(name object test_seconds)};
    my %expected = %{$constructor->{expected}};

    isa_ok($object, 'Miril::DateTime', "from '$name'");

    is($object->year,   $expected{year},   "year from '$name'");
    is($object->month,  $expected{month},  "month from '$name'");
    is($object->day,    $expected{day},    "day from '$name'");
    is($object->hour,   $expected{hour},   "hour from '$name'");
    is($object->minute, $expected{minute}, "minute from '$name'");
    is($object->second, $expected{second}, "second from '$name'") if $test_seconds;
}

###############
# FORMATTERS  #
###############

# $dt->as_epoch
is( $dt->as_epoch, '1304241300', 'epoch formatter' );

# $dt->as_iso
# this test will produce different results depending on timezone in which it is run
# disable until I figure out a good way to deal with this
# is( $dt->as_iso, '2011-05-01T12:15:00+03:00', 'iso formatter' );

# $dt->as_datetime
SKIP: 
{
    eval { require DateTime };
    skip "DateTime not installed", 2 if $@;

    my $datetime = $dt->as_datetime;

    isa_ok( $datetime, 'DateTime', 'DateTime formatter' );
    is( $datetime->ymd . ' ' . $datetime->hms, '2011-05-01 12:15:00', 'DateTime formatter values' );
}

# $dt->as_strftime
is( $dt->as_strftime('%Y-%m-%d %H:%M:%S'), '2011-05-01 12:15:00', 'strftime formatter');

# overload
is( "$dt", '1304241300', 'overload');

done_testing;
