package Miril::TypeLib;

# ABSTRACT: Library of Mouse type constraints

use strict;
use warnings;

use MouseX::Types;
use Ref::Explicit qw(arrayref hashref);

subtype TextId
	=> as      Str
	=> where   { /^\w+$/ }
	=> message { "Id contains non-alphanumeric symbols" };

class_type Topic    => { class => 'Miril::Topic' };
class_type Author   => { class => 'Miril::Author' };
class_type Type     => { class => 'Miril::Type' };
class_type Post     => { class => 'Miril::Post' };
class_type DateTime => { class => 'Miril::DateTime' };


class_type File => { class => 'Path::Class::File' };
class_type Dir  => { class => 'Path::Class::Dir' };

subtype Url    => as 'Str';
subtype TagUrl => as 'Str';

enum Status => qw(draft published);

subtype ArrayRefOfAuthor => as 'ArrayRef[Author]';
subtype ArrayRefOfTopic  => as 'ArrayRef[Topic]';
subtype ArrayRefOfType   => as 'ArrayRef[Type]';

subtype HashRefOfAuthor => as 'HashRef[Author]';
subtype HashRefOfTopic  => as 'HashRef[Topic]';
subtype HashRefOfType   => as 'HashRef[Type]';

coerce HashRefOfAuthor
    => from ArrayRefOfAuthor
    => via { hashref map { $_->id => $_ } @$_ };

coerce HashRefOfTopic
    => from ArrayRefOfTopic
    => via { hashref map { $_->id => $_ } @$_ };

coerce HashRefOfType
    => from ArrayRefOfType
    => via { hashref map { $_->id => $_ } @$_ };

subtype FieldValidation => as 'ArrayRef[Str]';

coerce FieldValidation
    => from Str
    => via { arrayref split /\s+/ };

### EXPORT SUBTYPES DEFINED HERE PLUS BUILT-IN MOUSE TYPES ###

sub type_storage 
{
	my %types = map { $_ => $_ } 
	qw(
		Str

		TextId
		Topic
		Author
		Type
		Post
		DateTime
		File
		Dir
		Url
		TagUrl
		Status
		ArrayRefOfAuthor
		ArrayRefOfTopic
		ArrayRefOfType
        HashRefOfAuthor
        HashRefOfTopic
        HashRefOfType
        FieldValidation
	);
	return \%types;
}	

1;
