package WWW::Publisher::Static::Store;

use strict;
use warnings;

use Any::Moose::Role;

requires 'get';

requires 'save';

requires 'delete';

requires 'search';

1;
