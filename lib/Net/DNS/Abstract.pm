package Net::DNS::Abstract;

use 5.010;
use Any::Moose;
use Module::Load;
use Net::DNS;
use Net::DNS::Packet;
use Net::DNS::ZoneFile;
use Data::Dump 'dump';

# ABSTRACT: Net::DNS interface to several DNS backends via API

# VERSION

=head1 SYNOPSIS

Net::DNS is the de-facto standard and battle tested perl DNS
implementation. Unfortunately we don't intercat with DNS via DNS
protocols but via 3rd party abstration layers that have all sorts of
quirks. We try to provide one unified interface here.

=head1 ATTRIBUTES

=head2 debug

=cut

has 'debug' => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub { 1 },
    lazy    => 1,
);

=head2 domain

the domain as a punycode string of the underlaying zone (required)

=cut

has 'domain' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 zone

the Net::DNS::Packet object of the underlaying zone

=cut

has 'zone' => (
    is      => 'rw',
    isa     => 'Net::DNS::Packet',
    default => sub { Net::DNS::Packet->new },
);

=head2 interface

defines the interface plugin to load (required)

=cut

has 'interface' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

before 'new' => sub {
    my ($class, %args) = @_;

    if (exists $args{interface}) {
        push(@{ $args{preload} }, $args{interface});
    }

    if (exists $args{preload}) {
        foreach my $mod (@{ $args{preload} }) {
            my $module = 'Net::DNS::Abstract::Plugins::' . ucfirst($mod);
            with $module;
            print STDERR __PACKAGE__ . ": loaded plugin: $module\n";
        }
    }

};

=head1 SUBROUTINES/METHODS

=head2 axfr

Do a zone transfer (actually poll a zone from a 3rd party provider) and
return a Net::DNS::Packet objects.

    axfr(['ns1.provider.net'])

=cut

sub axfr { }

=head2 update

Update a DNS zone via the respective backend plugin. This function takes
a Net::DNS update object and pushes it through to the backend plugin to
process it.

=cut

sub update {
    my ($self, $zone) = @_;

    unless (defined $zone) {
        $self->log('update(): missing "zone" parameter');
        return;
    }

    given (ref $zone) {
        when ('HASH') {
            $self->log('update(): zone has HASH format') if $self->debug;
            $self->our_to_net_dns($zone);
        }
        when ('') {
            $self->log('update(): zone is a Zonefile string') if $self->debug;
            $self->zonefile_to_net_dns($zone);
        }
        when ('Net::DNS::Packet') {
            $self->log('update(): zone is Net::DNS::Packet format')
                if $self->debug;
            $self->zone($zone);
        }
        default {
            $self->log('update(): unknown zone format');
        }
    }

    return;
}

=head2 create

Create a new zone in a DNS backend

=cut

sub create { }

=head2 delete

Delete a zone from a DNS backend

=cut

sub delete { }    ## no critic (ProhibitBuiltinHomonyms)

=head2 our_to_net_dns

Converts a zone from our generic representation to Net::DNS::Packet format.

Returns: Net::DNS::Packet object representation of the zone or undef on error

=cut

sub our_to_net_dns {
    my ($self, $zone) = @_;

    $self->log('to_net_dns(): ' . dump($zone)) if $self->debug;

    # create an empty zone
    $self->zone(Net::DNS::Packet->new($self->domain, 'IN', 'SOA'));

    # TODO this SOA record needs cleanup and debugging!
    $self->add_rr(
        update => {
            type    => 'SOA',
            name    => '',
            serial  => time,
            ns      => [ $zone->{ns}->[0]->{name} ],
            email   => $zone->{soa}->{email},
            retry   => $zone->{soa}->{retry},
            expire  => $zone->{soa}->{expire},
            refresh => $zone->{soa}->{refresh},
            ttl     => $zone->{soa}->{ttl},
        });

    # convert RR section
    foreach my $rr (@{ $zone->{rr} }) {
        $self->add_rr(update => $rr);
    }

    # convert NS section
    foreach my $rr (@{ $zone->{ns} }) {
        $self->add_rr(
            update => {
                type  => 'NS',
                name  => '',
                ttl   => $rr->{ttl} || 14400,
                value => $rr->{name},
            });
    }

    $self->log("to_net_dns(): DNS: " . dump($self->zone)) if $self->debug;

    return $self->zone;
}

=head2 zonefile_to_net_dns

Converts a zone from a Zonefile string representation to Net::DNS::Packet format.

Returns: Net::DNS::Packet object representation of the zone or undef on error

=cut

sub zonefile_to_net_dns {
    my ($self, $zonefile) = @_;

    $self->zone(Net::DNS::Packet->new($self->domain));
    $self->zone->push(update => Net::DNS::ZoneFile->parse($zonefile));

    return $self->zone;
}

=head2 add_rr

Add a Net::DNS::RR object to the zone attribute

Returns: true when successful, false otherwise

=cut

sub add_rr {
    my ($self, $section, $rr) = @_;

    $self->log('add_arr(): ' . dump($section, $rr)) if $self->debug;

    return
        unless $section =~
        m/^(header|question|answer|pre|prereq|authority|update|additional)$/;

    given ($rr->{type}) {
        when (/^SOA$/i) {
            $self->zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    mname   => $rr->{ns}->[0],
                    rname   => $rr->{email},
                    serial  => $rr->{serial} || time,
                    retry   => $rr->{retry},
                    refresh => $rr->{refresh},
                    expire  => $rr->{expire},
                    minimum => $rr->{ttl},
                    type    => $rr->{type},
                ));
            return 1;
        }
        when (/^A{1,4}$/i) {
            $self->zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    address => $rr->{value},
                ));
            return 1;
        }
        when (/^CNAME$/i) {
            $self->zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class => 'IN',
                    ttl   => $rr->{ttl} || 3600,
                    type  => $rr->{type},
                    cname => $rr->{value},
                ));
            return 1;
        }
        when (/^MX$/i) {
            $self->zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class      => 'IN',
                    ttl        => $rr->{ttl} || 14400,
                    type       => $rr->{type},
                    exchange   => $rr->{value},
                    preference => $rr->{prio},
                ));
            return 1;
        }
        when (/^SRV$/i) {
            my ($weight, $port, $target) = split(/\s/, $rr->{value}, 3);

            $self->zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class    => 'IN',
                    ttl      => $rr->{ttl} || 14400,
                    type     => $rr->{type},
                    target   => $target,
                    weight   => $weight,
                    port     => $port,
                    priority => $rr->{prio},
                ));
            return 1;
        }
        when (/^TXT$/i) {

            # split too long TXT records into multiple records on word boundary
            # limit: 255 chars
            my @txts = $rr->{value} =~ /(.{1,255})\W/gms;

            foreach my $txt (@txts) {
                $self->zone->push(
                    $section => Net::DNS::RR->new(
                        name => (
                              $rr->{name}
                            ? $rr->{name} . '.' . $self->domain
                            : $self->domain
                        ),
                        class   => 'IN',
                        ttl     => $rr->{ttl} || 3600,
                        type    => $rr->{type},
                        txtdata => $txt,
                    ));
            }

            return 1;
        }
        when (/^NS$/i) {
            $self->zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 14400,
                    type    => $rr->{type},
                    nsdname => $rr->{value},
                ));
            return 1;
        }
        default {
            $self->log('add_arr(): '
                    . $self->domain
                    . ": unsupported record type: "
                    . $rr->{type});
            return;
        }
    }

    return;
}

=head2 from_net_dns

Convert a Net::DNS object into our normalized format

Returns: our normalized format as HASHREF or undef on error

=cut

sub from_net_dns {
    my ($self) = @_;

    my $domain = $self->domain;

    $self->log("from_net_dns(): DOMAIN: >> $domain <<");

    my @rrs = (
          $self->zone->authority
        ? $self->zone->authority
        : $self->zone->answer
    );

    my $zone;
    foreach my $rr (@rrs) {
        given ($rr->type) {
            my $name = $rr->name;
            $name =~ s/\.?$domain$//;
            when ('SOA') {
                $zone->{soa} = {
                    retry   => $rr->retry,
                    email   => $rr->rname,
                    refresh => $rr->refresh,
                    ttl     => $rr->ttl,
                    expire  => $rr->expire,
                };
                $zone->{domain} = $rr->name;
                $domain = $zone->{domain};
                $self->domain($domain);
            }
            when ('NS') {
                push(
                    @{ $zone->{ns} },
                    { name => $rr->nsdname, ttl => $rr->ttl });
                push(
                    @{ $zone->{rr} }, {
                        name => $name || undef,
                        ttl  => $rr->ttl,
                        type => $rr->type,
                        value => $rr->nsdname,
                    });
            }
            when (/^A{1,4}$/) {
                push(
                    @{ $zone->{rr} }, {
                        name => $name || undef,
                        ttl  => $rr->ttl,
                        type => $rr->type,
                        value => $rr->address,
                    });
            }
            when ('CNAME') {
                push(
                    @{ $zone->{rr} }, {
                        name => $name || undef,
                        ttl  => $rr->ttl,
                        type => $rr->type,
                        value => $rr->cname,
                    });
            }
            when ('MX') {
                push(
                    @{ $zone->{rr} }, {
                        name => $name || undef,
                        ttl  => $rr->ttl,
                        type => $rr->type,
                        prio => $rr->preference,
                        value => $rr->exchange,
                    });
            }
            when ('SRV') {
                push(
                    @{ $zone->{rr} }, {
                        name => $name || undef,
                        ttl  => $rr->ttl,
                        type => $rr->type,
                        prio => $rr->priority,
                        value => $rr->weight . ' '
                            . $rr->port . ' '
                            . $rr->target,
                    });
            }
            when ('TXT') {
                push(
                    @{ $zone->{rr} }, {
                        name => $name || undef,
                        ttl  => $rr->ttl,
                        type => $rr->type,
                        value => $rr->txtdata,
                    });
            }
        }

    }

    return $zone;
}

=head2 log

print log message to STDERR including this module's name

Returns: nothing

=cut

sub log {    ## no critic (ProhibitBuiltinHomonyms)
    my ($self, $msg) = @_;

    return unless (ref \$msg eq 'SCALAR');

    print STDERR __PACKAGE__ . ": $msg\n";

    return;
}

1;
