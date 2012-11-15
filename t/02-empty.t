#!perl -T
use strict;

use Test::More tests => 4;

use Net::LimeLight::Reporting;
use Net::LimeLight::Reporting::Request;

my $report = Net::LimeLight::Reporting->new(
    username => 'weee',
    password => 'random'
);
isa_ok($report, 'Net::LimeLight::Reporting');

#my $ret = $purge->create_purge_request;
#ok(!defined($ret), 'empty request does nothing');

#my $ret2 = $purge->create_purge_request({});
#ok(!defined($ret2), 'wrong type requests do nothing');

#my $ret3 = $purge->create_purge_request([]);
#ok(!defined($ret3), 'no requests does nothing');

