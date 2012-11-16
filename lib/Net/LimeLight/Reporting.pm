package Net::LimeLight::Reporting;

use strict;
use warnings;
use Carp;

use DateTime::Format::ISO8601;
use Moose;
use SOAP::Lite;

=head1 NAME

Net::LimeLight::Reporting - LimeLight Reporting Service API

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  # For SOAP RPC specs, see: https://soap.llnw.net/ReportingService/Service.asmx
  use Net::LimeLight::Reporting;

  my $client = Net::LimeLight::Reporting->new(
      username => 'luxuser',
      password => 'luxpass'
  );
  $client->auth()
      or $client->error();

  # * getAvailableReports
  #     This method returns a collection of available reports for a user.
  #     The returned report objects will be used with other methods.
  $client->reports();

  # * getAvailableCategories
  #     This method returns a collection of available categories for a report.
  #     The returned category objects will be used with other methods.
  $client->categories($reports->[0]);

  # * getAvailableTimeRanges
  #     This method returns a collection of available time ranges for a report.
  #     The return time range objects will be used with other methods.
  $client->time_ranges($reports->[0]);

  # * getReportData
  #     This method returns the raw report data for a report, category and time range.
  #     The user may set an order-by (Allowed: item_name, num_bytes, num_seconds, num_users and num_requests)
  #      and direction in this param (Allowed: asc, desc).
  #      Examples 'item_name asc', 'num_bytes desc', 'num_requests'.
  $client->report_data($reports->[0], $categories->[0], $ranges->[1], ($orderby || undef));

  # * getCurrentTraffic
  #     Return the current traffic in bytes/sec in and bytes/sec out.
  #     This method throws a CustomerNotConfiguredException if the customer is not configured to receive traffic data through the API.
  #     This method throws a TrafficDatabaseUnreachableException if the traffic database cannot be contacted.
  $client->current_traffic();

  # * getDiskUsage
  #     This method returns the raw disk usage 5-minute sample data for a specific time range.
  #     The sample data is returned in a SOAPNetworkUsage strcuture.
  $client->disk_usage();

  # * getNetworkUsageSections
  #     This method returns the network usage sections available for a report.
  $client->network_usage_sections($reports->[0]);

  # * getNetworkUsage
  #     This method returns the raw network usage data for a report, usage section, start date-time, end date-time and interval.
  #     The interval is the number of seconds between samples. Typical values are 60 (=1 minute) and 300 (=5 minutes).
  #     The returned data will include a start and end date-time, which may be different depending on data availablility.
  $client->network_usage($reports->[0], $sections->[1], $startDateTime, $endDateTime, $interval);

  # * getReportSummary(deprecated)
  # $client->report_summary();

  # * getAvailableCounters
  #     This methods returns the reports for WM Counter stats.
  # $client->counters();
  # $client->counter_ranges();
  # $client->counter_sections();
  # $client->counter_usage();

  # $client->streams();
  # $client->live_wm_aggregate();
  # $client->live_wm_counters();

=head1 METHODS

=cut

has '_date_parser' => (
    is => 'rw',
    lazy => 1,
    default => sub {
        return DateTime::Format::ISO8601->new;
    }
);

=head2 error

Recent fault of SOAP access

=cut

has 'error' => (
    is => 'rw',
    isa => 'Any'
);

=head2 access

SOAPAccess access token object (for internal use)

=cut

has 'access' => (
    is => 'rw',
    isa => 'Ref',
);

=head2 username

Get/Set your LimeLight Network CONTROL username.

=cut

has 'username' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

=head2 password

Get/Set your LimeLight Network CONTROL password.

=cut

has 'password' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

=head2 proxy

The address to send SOAP requests.  Defaults to C<http://soap.llnw.net/Reporting/Service.asmx>.

=cut

has 'proxy' => (
    is => 'rw',
    isa => 'Str',
    default => sub { 'http://soap.llnw.net/ReportingService/Service.asmx' }
);

=head2 uri

The uri to use for SOAP requests.  Defaults to C<http://soap.llnw.net/Reporting>.

=cut

has 'uri' => (
    is => 'rw',
    isa => 'Str',
    default => sub { 'http://www.llnw.com/Reporting' }
);

=head2 wsdl

WSDL uri

=cut

has 'wsdl' => (
    is => 'rw',
    isa => 'Str',
    default => sub { 'http://soap.llnw.net/ReportingService/Service.asmx?WSDL' }
);

no Moose;

=head2 debug([enable])

Specify to output request/response of SOAP RPC

=over 4

=item I<enable>

Specify debug mode enable or disable. (Default: enable)

=back

=cut

sub debug {
    my $self = shift;
    no strict 'subs';
    no strict 'refs';
    use LWP::UserAgent;
    if (not(@_) or $_[0]) {
        use Data::Dumper;
        $self->{_lwp_ua_request} = \&LWP::UserAgent::request;
        *LWP::UserAgent::request = sub {
            my $r = $self->{_lwp_ua_request}->(@_);
            warn Dumper {res => $r};
            $r;
        };
    } else {
        if ($self->{_lwp_ua_request}) {
            *LWP::UserAgent::request = delete $self->{_lwp_ua_request};
        }
    }
}

=head2 error_message

=cut

sub error_message {
    my $e = (shift)->error;
    return '' unless $e;
    sprintf "SOAP RPC Error(%s): %s, %s", $e->{code}, $e->{message}, $e->{detail};
}

=head2 _soap

SOAP accessor object (for internal use)

=cut

sub _soap {
    my ($self, %args) = @_;

    my $soap = SOAP::Lite->new(
        service => $self->wsdl,
        proxy => $self->proxy,
        uri => $self->uri,
        soapversion => '1.2',
        envprefix => 'soap12',
        #   attr => { 'xmlns:tns' => $self->uri },
    );
    $soap->ns('http://www.llnw.com/Reporting/encodedTypes', 'types');
    $soap->ns('http://www.llnw.com/Reporting', 'tns'); # later namespace is default namespace of method...
    if ($args{method}) {
        $soap->on_action(sub { $self->uri . '/' . $args{method} });
    }
    $soap;
}

=head2 rpc

LimeLight SOAP rpc shortcut

=cut

sub rpc {
    my ($self, $method, @args) = @_;
    $self->error(undef);
    my $soap = $self->_soap(method => $method);

    my $methodobj = SOAP::Data->name('tns:' . $method)->prefix('tns');
    my $res;
    if ($method eq 'getAccess') {
        $res = $soap->call($methodobj, @args);
    } else {
        $res = $soap->call($methodobj, $self->access, @args);
    }
    if ($res->fault) {
        my $f = $res->fault;
        $self->error({code => $f->{Code}->{Value}, message => $f->{Reason}->{Text}, detail => $f->{Detail}});
        return undef;
    }
    $res;
}

=head2 auth

Authenticate and get access token for RPC

=cut

sub auth {
    my $self = shift;
    my $res = $self->rpc('getAccess', (
        SOAP::Data->new(name => 'username', value => $self->username),
        SOAP::Data->new(name => 'password', value => $self->password),
    ));
    unless ($res) {
        carp $self->error_message();
        return undef;
    }
    my $access = $res->valueof('//getAccessResult');
    my $accessobj = SOAP::Data->name('userAccess' => \SOAP::Data->value(
        map { SOAP::Data->name($_ => $access->{$_})->type('string'); } keys(%$access)
    ))->type('types:SOAPAccess');
    $self->access( $accessobj );

    $self->access;
}

=head2 reports

Get reports list and returns as arrayref

=cut

sub reports {
    my $self = shift;

    my $res = $self->rpc('getAvailableReports');
    unless ($res) {
        carp $self->error_message;
        return undef;
    }
    #TODO return [] if blank ('')
    $res->valueof( '//getAvailableReportsResult' );
}

=head2 categories($report)

=cut

sub categories {
}

=head2 time_ranges($report)

=cut

sub time_ranges {
}

=head2 report_data($report, $category, $time_range, $orderby)

=cut

sub report_data {
}



# sub get_all_purge_statuses {
#     my ($self, $detail) = @_;

#     my $soap = $self->_soap;
#     $soap->on_action(sub { $self->uri.'/GetAllPurgeStatuses' });
#     my $header = $self->_header;

#     my $res_details = 'false';
#     if($detail) {
#         $res_details = 'true';
#     }

#     my $res = $soap->call(
#         SOAP::Data->new(
#             name => 'GetAllPurgeStatuses',
#             attr => { xmlns => $self->uri },
#         ) => SOAP::Data->type('string')->name(IncludeDetail => $res_details),
#         $header
#     );
#     if($res->fault) {
#         die join(', ',
#             $res->faultcode,
#             $res->faultstring,
#             $res->faultdetail
#         );
#     }

#     # Save me from carpal tunnel
#     my $env_prefix = '//GetAllPurgeStatusesResponse/GetAllPurgeStatusesResult';

#     my $resp = Net::LimeLight::Purge::StatusResponse->new(
#         completed_entries => $res->valueof("$env_prefix/CompletedEntries"),
#         total_entries => $res->valueof("$env_prefix/TotalEntries")
#     );

#     # If we have statuses, put them into the response!
#     if($res->match("$env_prefix/EntryStatuses/PurgeEntryStatus")) {
#         foreach my $r ($res->dataof) {
#             $resp->add_request(
#                 Net::LimeLight::Purge::Request->new(
#                     url => $r->value->{Url},
#                     shortname => $r->value->{Shortname},
#                     regex => ($r->value->{Regex} eq 'true') ? 1 : 0,
#                     completed => ($r->value->{Completed} eq 'true') ? 1 : 0,
#                     batch_number => $r->value->{BatchNumber},
#                     completed_date => $self->_date_parser->parse_datetime(
#                         $r->value->{CompletedDate}
#                     )
#                 )
#             );
#         }
#     }


#     return $resp;
# }

=head1 AUTHOR

tagomoris, C<< <tagomoris at cpan.org> >>

Thanks to Cory G Watson, C<< <gphat at cpan.org> >> (for Net::LimeLight::Purge)

=head1 REPOSITORY

L<http://github.com/tagomoris/Net-LimeLight-Reporting>

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2012- tagomoris, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
