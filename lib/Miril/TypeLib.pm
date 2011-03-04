package Miril::TypeLib;

use strict;
use warnings;

use MouseX::Types; 

subtype TextId
	=> as      Str
	=> where   { /^\w+$/ }
	=> message { "Id contains non-alphanumeric symbols" };

class_type Topic      => { class => 'Miril::Topic' };
class_type Author     => { class => 'Miril::Author' };
class_type Type       => { class => 'Miril::Type' };
class_type Post       => { class => 'Miril::Post' };
class_type DateTime   => { class => 'Miril::DateTime' };

subtype ArrayRefOfTopic => as 'ArrayRef[Topic]';

class_type File => { class => 'Path::Class::File' };
class_type Dir  => { class => 'Path::Class::Dir' };

subtype Url    => as 'Str';
subtype TagUrl => as 'Str';

enum Status => qw(draft published);

### EXPORT SUBTYPES DEFINED HERE PLUS BUILT-IN MOUSE TYPES ###

sub type_storage 
{
	my %types = map { $_ => $_ } 
	# mouse
	qw(
		Str
	),
	# miril
	qw(
		TextId
		Topic
		Author
		Type
		Post
		DateTime
		ArrayRefOfTopic
		File
		Dir
		Url
		TagUrl
		Status
	);
	return \%types;
}	

1;
