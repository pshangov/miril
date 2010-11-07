package WWW::Publisher::Static::Store;

use strict;
use warnings;

use Mouse::Role;

requires 'get';

requires 'save';

requires 'delete';

requires 'search';

1;
