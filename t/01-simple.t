#!perl -T
use strict;

use Test::More tests => 2;

use Net::LimeLight::Reporting;
use Net::LimeLight::Reporting::Request;

my $purge = Net::LimeLight::Reporting->new(
    username => 'weee',
    password => 'random'
);
isa_ok($purge, 'Net::LimeLight::Reporting');

my $req = Net::LimeLight::Reporting::Request->new(
);
isa_ok($req, 'Net::LimeLight::Reporting::Request');

