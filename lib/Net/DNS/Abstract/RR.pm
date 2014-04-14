package Net::DNS::Abstract::RR;

use 5.010;
use Mouse;


=head2 domain

the domain as a punycode string of the underlaying zone (required)

=cut

has 'domain' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);


=head2 add

Add a Net::DNS::RR object to the zone attribute

Returns: true when successful, false otherwise

=cut

sub add {
    my ($self, $zone, $section, $rr) = @_;

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
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    mname   => $rr->{ns}->[0],
                    rname   => $rr->{email} || 'email@domain.tld',
                    serial  => $rr->{serial} || time,
                    retry   => $rr->{retry},
                    refresh => $rr->{refresh},
                    expire  => $rr->{expire},
                    minimum => $rr->{ttl},
                    type    => $rr->{type},
                ));
            return $zone;
        }
        when (/^A{1,4}$/i) {
            $zone->push(
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
            return $zone;
        }
        when (/^CNAME$/i) {
            $zone->push(
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
            return $zone;
        }
        when (/^MX$/i) {
            $zone->push(
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
            return $zone;
        }
        when (/^SRV$/i) {
            my ($weight, $port, $target) = split(/\s/, $rr->{value}, 3);

            $zone->push(
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
            return $zone;
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
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    txtdata => $rr->{value},
                ));

            #}

            return $zone;
        }
        when (/^NS$/i) {
            $zone->push(
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
            return $zone;
        }
        default {
            warn('add_arr(): '
                    . $self->domain
                    . ": unsupported record type: "
                    . $rr->{type});
            return;
        }
    }

    return;
}

1;
