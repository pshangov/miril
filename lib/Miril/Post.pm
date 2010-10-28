package Miril::Post;

use strict;
use warnings;

use Mouse;

has 'id' => 
(
	is => 'ro',
);

has 'title' => 
(
	is => 'ro',
);

has 'body' => 
(
	is => 'ro',
);

has 'teaser' => 
(
	is => 'ro',
);

has 'source' => 
(
	is => 'ro',
);

has 'url' => 
(
	is => 'ro',
);

has 'author' => 
(
	is => 'ro',
);

has 'published' => 
(
	is => 'ro',
);

has 'modified' => 
(
	is => 'ro',
);

has 'topics' => 
(
	is => 'ro',
);

has 'type' => 
(
	is => 'ro',
);

has 'out_path' => 
(
	is => 'ro',
);
	
has 'tag_url' => 
(
	is => 'ro',
);	

1;
