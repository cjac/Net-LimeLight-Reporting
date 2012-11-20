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
  $client->disk_usage($reports->[0], $ranges->[0]);

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

=head2 access_token($method_name)

SOAP API access token generator

=cut

sub access_token {
    my ($self, $method) = @_;
    my $name;
    if (
        $method eq 'getAvailableCategories' or
        $method eq 'getAvailableTimeRanges' or
        $method eq 'getCounterRanges' or
        $method eq 'getCounterSections' or
        $method eq 'getCounterUsage' or
        $method eq 'getDiskUsage' or
        $method eq 'getLiveWMAggregate' or
        $method eq 'getLiveWMCounters' or
        $method eq 'getNetworkUsage' or
        $method eq 'getNetworkUsageSections' or
        $method eq 'getReportData' or
        $method eq 'getReportSummary' or
        $method eq 'getStreams'
    ) {
        $name = 'soap_access';
    } elsif ($method eq 'getCurrentTraffic') {
        $name = 'access_token';
    } elsif (
        $method eq 'getAvailableCounters' or
        $method eq 'getAvailableReports'
      ) {
        $name = 'userAccess';
    } else {
        die "unknown method name for SOAP RPC: $method";
    }
    $self->_soap_data($self->access, $name, 'types:SOAPAccess');
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

=head2 _soap_data

Build named (and typed) SOAP::Data object

=cut

sub _soap_data {
    my ($self, $obj, $name, $type) = @_;
    return SOAP::Data->name($name => \SOAP::Data->value(
        map { SOAP::Data->name($_ => $obj->{$_})->type('string') } keys(%$obj)
    ))->type($type);
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
        $res = $soap->call($methodobj, $self->access_token($method), @args);
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
    $self->access( $access );
    $self;
}

=head2 current_traffic()

=cut

sub current_traffic {
    my $self = shift;

    my $res = $self->rpc('getCurrentTraffic');
    unless ($res) {
        carp $self->error_message;
        return undef;
    }
    #TODO return [] if blank ('')
    $res->valueof( '//getCurrentTrafficResult' );
}

=head2 reports()

Get reports list and returns as arrayref of {desc=>'',name=>'',id=>'',key=>''}

=cut

sub reports {
    my ($self) = shift;

    my $res = $self->rpc('getAvailableReports');
    unless ($res) {
        carp $self->error_message;
        return undef;
    }
    my $result = $res->valueof( '//getAvailableReportsResult' );
    unless ($result and $result->{Item}) {
        return [];
    }
    $result->{Item};
}

=head2 categories($report)

Get categories of report and returns as arrayref of {desc=>'',name=>'',id=>'',key=>''}
List of name is assumed as:
 [
  'Day','Day of Week','Duration','Errors','File Size','File Type','Geo','Hour','Hour of Day',
  'Missing Files','Published Hosts','Referer Domains','Status','URL Prefixes','URLs','User Agent',
 ]

=cut

sub categories {
    my ($self, $report) = @_;

    my $res = $self->rpc('getAvailableCategories', $self->_soap_data($report, 'report', 'types:SOAPAvailableReport'));
    unless ($res) {
        carp $self->error_message;
        return undef;
    }
    my $result = $res->valueof( '//getAvailableCategoriesResult' );
    unless ($result and $result->{Item}) {
        return [];
    }
    $result->{Item};
}

=head2 category($category_name, $report)

Shortcut method to get a category with specified name from list

=cut

sub category {
    my ($self, $name, $report) = @_;
    my $categories = $self->categories($report);
    unless($categories and scalar(@{$categories}) > 0) {
        return undef;
    }
    my @filtered = grep { $_->{name} eq $name } @$categories;
    unless(@filtered) {
        carp "No one category matches $name found";
        return undef;
    }
    if (scalar(@filtered) > 1) {
        carp "2 or more category object found matches $name:" . scalar(@filtered);
        return undef;
    }
    $filtered[0];
}

=head2 time_ranges($report)

Get arrayref of available time ranges like {sum_id=>'',desc=>'',name=>'',type=>'',key=>'',end=>'',start=>''}
List of name is assumed as: ['monthly','weekly','daily','hourly']

'start' and 'end' have unix time (seconds from epoch)

Timezome of ranges are assumed as MST(-0700), AZ, HQ of limelight

=cut

sub time_ranges {
    my ($self, $report) = @_;

    my $res = $self->rpc('getAvailableTimeRanges', $self->_soap_data($report, 'report', 'types:SOAPAvailableReport'));
    unless ($res) {
        carp $self->error_message;
        return undef;
    }
    my $result = $res->valueof( '//getAvailableTimeRangesResult' );
    unless ($result and $result->{Item}) {
        return [];
    }
    $result->{Item};
}

=head2 report_data($report, $category, $time_range, [$orderby])

Get report data

=over 4

=item I<orderby>

Specify order by string, like "$fieldname $direction". Fieldname is one of 'item_name', 'num_bytes', 'num_seconds', 'num_users' and 'num_requests'. Direction is one of 'asc' and 'desc'.

Examples: 'item_name asc', 'num_bytes desc', 'num_requests'.

=cut

sub report_data {
    my ($self, $report, $category, $time_range, $orderby) = @_;

    my $res = $self->rpc('getAvailableTimeRanges', (
        $self->_soap_data($report, 'report', 'types:SOAPAvailableReport'),
        $self->_soap_data($category, 'category', 'types:SOAPAvailableCategory'),
        $self->_soap_data($time_range, 'timeRange', 'types:SOAPAvailableTimeRange'),
        SOAP::Data->name('orderBy' => ($orderby || ''))->type('string'),
    ));
    unless ($res) {
        carp $self->error_message;
        return undef;
    }
    my $result = $res->valueof( '//getReportDataResult' );
    unless ($result and $result->{Item}) {
        return [];
    }
    $result->{Item};
}

=head2 disk_usage($report, $time_range)

Get disk usage information(s) as {values=>$values,startTime=>'',startTimeEpoch=>'',endTime=>'',endTimeEpoch=>'',interval=>'',nsamples=>''}

$values: arrayref of {type=>'',label=>'',units=>'',samples=>[num]}

=cut

sub disk_usage {
    my ($self, $report, $time_range) = @_;

    my $res = $self->rpc('getDiskUsage', (
        $self->_soap_data($report, 'report', 'types:SOAPAvailableReport'),
        $self->_soap_data($time_range, 'timerange', 'types:SOAPAvailableTimeRange'),
    ));
    unless ($res) {
        carp $self->error_message;
        return undef;
    }
    my $r = $res->valueof( '//getDiskUsageResult' );
    unless ($r) {
        return {};
    }
    my $data = +{
        (map { ($_ => $r->{$_}) } qw(startTime startTimeEpoch endTime endTimeEpoch interval nsamples))
    };
    if ($r->{variables} and $r->{variables}->{Item}) {
        my @values = ();
        foreach my $item (@{$r->{variables}->{Item}}) {
            push @values, +{
                type => $item->{type},
                label => $item->{label},
                units => $item->{units},
                samples => ($item->{samples} || {})->{Item},
            };
        }
        $data->{values} = [@values];
    }
    $data;
}

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

1;
