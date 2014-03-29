package Net::DNS::Abstract::Types;

use 5.010;
use Net::DNS::ZoneFile::Fast;
use Net::DNS::Packet;

use Mouse::Util::TypeConstraints;
use MouseX::Types -declare => [qw(Zone)];
use MouseX::Types::Mouse;

use experimental 'smartmatch';

use Data::Dump qw/dump/;

type 'Zone',
    as class_type('Net::DNS::Packet'),
    message { "$_ is not a Net::DNS::Packet" };

subtype Zone,     as 'Zone';

for my $type ( 'Zone', Zone ) {
    coerce($type, 
        from 'Str',     via { zonefile_to_net_dns($_); },
        from 'HashRef', via { our_to_net_dns($_); },
    );
}

=head2 zonefile_to_net_dns

Converts a zonefile to Net::DNS::Packet format.

Returns: Net::DNS::Packet object representation of the zone or undef on error

=cut

sub zonefile_to_net_dns {
    my $zonefile = shift;

    my $zone = Net::DNS::ZoneFile::Fast::parse($zonefile);
    return unless $zone;
    my $domain;
    foreach my $rr (@{$zone}){
        next unless $rr->isa('Net::DNS::RR::SOA');
        $domain = $rr->name;
        last;
    }
    my $nd = Net::DNS::Packet->new($domain);
    $nd->push(update => @$zone);
    return $nd;
}

=head2 our_to_net_dns

Converts a zone from our generic representation to Net::DNS::Packet format.

Returns: Net::DNS::Packet object representation of the zone or undef on error

=cut

sub our_to_net_dns {
    my ($zone) = @_;

    #$self->log('to_net_dns(): ' . dump($zone)) if $self->debug;

    # create an empty zone
    my $domain = $zone->{domain};
    my $nda_zone = Net::DNS::Packet->new($domain, 'IN', 'SOA');

    # TODO this SOA record needs cleanup and debugging!
    add_rr($nda_zone, $domain, 
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
        add_rr($nda_zone, $domain, update => $rr);
    }

    # convert NS section
    foreach my $rr (@{ $zone->{ns} }) {
        add_rr($nda_zone, $domain,
            update => {
                type  => 'NS',
                name  => '',
                ttl   => $rr->{ttl} || 14400,
                value => $rr->{name},
            });
    }

    #$self->log("to_net_dns(): DNS: " . dump($self->zone)) if $self->debug;

    return $nda_zone;
}

=head2 add_rr

Add a Net::DNS::RR object to the zone attribute

Returns: true when successful, false otherwise

=cut

sub add_rr {
    my ($zone, $domain, $section, $rr) = @_;

    #$self->log('add_arr(): ' . dump($section, $rr)) if $self->debug;

    return
        unless $section =~
        m/^(header|question|answer|pre|prereq|authority|update|additional)$/;

    given ($rr->{type}) {
        when (/^SOA$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
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
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    address => $rr->{value},
                ));
            return 1;
        }
        when (/^CNAME$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class => 'IN',
                    ttl   => $rr->{ttl} || 3600,
                    type  => $rr->{type},
                    cname => $rr->{value},
                ));
            return 1;
        }
        when (/^MX$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
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

            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
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
            # FIXME this currently breaks SPF records as it cuts off the
            # trailing '~all'. temporarily disabled by [norbu09]
            #my @txts = $rr->{value} =~ /(.{1,255})\W/gms;

            #foreach my $txt (@txts) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    txtdata => $rr->{value},
                ));

            #}

            return 1;
        }
        when (/^NS$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 14400,
                    type    => $rr->{type},
                    nsdname => $rr->{value},
                ));
            return 1;
        }
        default {
            warn('add_arr(): '
                    . $domain
                    . ": unsupported record type: "
                    . $rr->{type});
            return;
        }
    }

    return;
}

1;
