use inc::Module::Install;

name     'Net-LimeLight-Reporting';
all_from 'lib/Net/LimeLight/Reporting.pm';

build_requires 'Test::More';

requires 'DateTime::Format::ISO8601';
requires 'Moose';
requires 'MooseX::AttributeHelpers';
# requires 'SOAP::Lite'; # 0.715 is broken.... (now includes 0.714 under lib/)
requires 'LWP::Protocol::https';
requires 'Crypt::SSLeay';

WriteAll;

