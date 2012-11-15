use inc::Module::Install;

name     'Net-LimeLight-Reporting';
all_from 'lib/Net/LimeLight/Reporting.pm';

build_requires 'Test::More';

requires 'DateTime::Format::ISO8601';
requires 'Moose';
requires 'MooseX::AttributeHelpers';
requires 'SOAP::Lite';
requires 'LWP::Protocol::https';
requires 'Crypt::SSLeay';

WriteAll;

