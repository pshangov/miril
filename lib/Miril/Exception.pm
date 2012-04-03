package Miril::Exception;

# ABSTRACT: Base exception class

use Exception::Class ( 'Miril::Exception' => { fields => 'errorvar' } );

1;
