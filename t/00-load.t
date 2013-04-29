#!perl -T

use lib 'lib';
use Test::More tests => 1;

BEGIN {
    use_ok( 'Net::DNS::Abstract' ) || print "Bail out!\n";
}

diag( "Testing Net::DNS::Abstract $Net::DNS::Abstract::VERSION, Perl $], $^X" );
