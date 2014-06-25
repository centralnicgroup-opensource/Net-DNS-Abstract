package Net::DNS::Abstract::Types;

use Modern::Perl;

use Mouse::Util::TypeConstraints;
use MouseX::Types -declare => [qw(Zone)];
use MouseX::Types::Mouse;
use Net::DNS::ZoneFile::Fast;
use Net::DNS::Packet;
use Data::Dump 'dump';

use lib 'lib';
use Net::DNS::Abstract::RR;

# ABSTRACT: Net::DNS::Abstract type definitions and methods

type 'Zone', as class_type('Net::DNS::Packet'),
    message { "$_ is not a Net::DNS::Packet" };

subtype Zone, as 'Zone';

for my $type ('Zone', Zone) {
    coerce(
        $type, from 'Str',
        via { zonefile_to_net_dns($_); },
        from 'HashRef',
        via { our_to_net_dns($_); },
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
    foreach my $rr (@{$zone}) {
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

    my $nda_rr = Net::DNS::Abstract::RR->new(domain => $domain);

    # TODO this SOA record needs cleanup and debugging!
    $nda_zone = $nda_rr->add(
        $nda_zone,
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
        next unless exists $rr->{type};
        $nda_zone = $nda_rr->add($nda_zone, update => $rr);
    }

    # convert NS section
    foreach my $rr (@{ $zone->{ns} }) {
        $nda_zone = $nda_rr->add(
            $nda_zone,
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

1;
