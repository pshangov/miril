package Moose::Store;

use strict;
use warnings;

use Mouse::Role;

requires 'get_post';

requires 'get_posts';

requires 'save';

requires 'delete';

requires 'get_latest';

requires 'add_to_latest';

1;
