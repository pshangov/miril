package Miril::DateTime;

use POSIX qw(strftime);

sub new      { bless \$_[1], $_[0] }
sub epoch    { $$_[0] }
sub iso      { time2iso($$_[0]) }
sub strftime { strftime($_[1], localtime($$_[0])) }

1;
