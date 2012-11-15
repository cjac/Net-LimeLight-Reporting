#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Net::LimeLight::Reporting' );
}

diag( "Testing Net::LimeLight::Reporting $Net::LimeLight::Reporting::VERSION, Perl $], $^X" );
