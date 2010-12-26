package WWW::Publisher::Static::Store;

use strict;
use warnings;

use Any::Moose::Role;

requires 'get_post_by_id';

requires 'save';

requires 'delete';

requires 'search';

1;
