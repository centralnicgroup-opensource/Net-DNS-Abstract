package Net::DNS::Abstract::Plugins::Internetx;

use 5.010;
use Any::Moose;
use Net::DNS;
use Net::DNS::Abstract::Plugins::Daemonise;

extends 'Net::DNS::Abstract';

has 'ix_transport' => (
    is      => 'rw',
    default => sub { Net::DNS::Abstract::Plugins::Daemonise->new() },
    lazy    => 1,
);

=head2 provides

Register in the Net::DNS dispatch table for backend calls

=cut

sub provides {
    my ($self) = @_;

    return {
        internetx => { axfr => \&ix_status_zone, update => \&ix_update_zone } };
}

=head2 ix_status_zone

Query a DNS zone via InternetX

=cut

sub ix_status_zone {
    my ($self, $domain, $ns) = @_;

    my $hash = {
        command => 'status_zone',
        options => { domain => $domain, ns => $ns, interface => 'internetx' },
    };
    my $res = $self->ix_transport->ask($hash);
    my $zone = $self->_parse_ix($res->{response} || $res);
    return $zone;
}

=head2 ix_update_zone

Update InternetX based on a Net::DNS update object

=cut

sub ix_update_zone {
    my ($self, $update) = @_;

    my $hash = {
        command => 'update_zone',
        options => $self->from_net_dns($update),
    };
    $hash->{options}->{interface} = 'internetx';
    my $res = $self->ix_transport->ask($hash);
    my $zone = $self->_parse_ix($res->{response} || $res);

    return $zone;
}

=head2 _parse_ix

Parse a raw IX answer into someting that we can deal with. This will
return a Net::DNS object.

=cut

sub _parse_ix {
    my ($self, $data) = @_;

    my $zone = $data->{data}->{zone};
    given ($data->{code}) {
        when (/^N/) { $data->{status} = 'pending' }
        when (/^S/) { $data->{status} = 'success' }
        when (/^E/) { $data->{status} = 'error' }
    }

    # TODO this should be error handling as Net::DNS expects it!
    return { error => $data } unless $data->{status} eq 'success';
    return $data unless $zone;

    my $domain = $zone->{name}->{content};
    my $packet = new Net::DNS::Packet($domain, 'AXFR');

    $packet->push(
        answer => new Net::DNS::RR(
            name    => $domain,
            mname   => $zone->{nserver}->[0]->{name}->{content},
            rname   => $zone->{soa}->{email}->{content},
            retry   => $zone->{soa}->{retry}->{content},
            refresh => $zone->{soa}->{refresh}->{content},
            expire  => $zone->{soa}->{expire}->{content},
            minimum => $zone->{soa}->{ttl}->{content},
            type    => 'SOA',
        ));

    if (ref $zone->{rr} eq 'ARRAY') {
        foreach my $rr (@{ $zone->{rr} }) {
            $rr->{name}->{content} = ''
                unless exists $rr->{name}->{content};
            $rr->{name}->{content} = ''
                if ($rr->{name}->{content} eq $domain);
            $rr->{value}->{content} =~ s/\.+$//;
            $packet->push(
                answer => $self->rr_from_hash({
                        ttl => $rr->{ttl}->{content} || 3600,
                        name  => $rr->{name}->{content},
                        value => $rr->{value}->{content},
                        type  => uc($rr->{type}->{content}),
                        prio  => $rr->{pref}->{content} || undef,
                    },
                    $domain
                ));
        }
    }
    else {
        $zone->{rr}->{name}->{content} = ''
            unless exists $zone->{rr}->{name}->{content};
        $zone->{rr}->{name}->{content} = ''
            if ($zone->{rr}->{name}->{content} eq $domain);
        $zone->{rr}->{value}->{content} =~ s/\.+$//;
        $packet->push(
            answer => $self->rr_from_hash({
                    ttl => $zone->{rr}->{ttl}->{content} || 3600,
                    name  => $zone->{rr}->{name}->{content},
                    value => $zone->{rr}->{value}->{content},
                    type  => uc($zone->{rr}->{type}->{content}),
                    prio  => $zone->{rr}->{pref}->{content} || undef,
                },
                $domain
            ));
    }
    if ($zone->{main}) {
        $packet->push(
            answer => $self->rr_from_hash({
                    ttl => $zone->{main}->{ttl}->{content} || 3600,
                    name  => '',
                    value => $zone->{main}->{value}->{content},
                    type  => 'A'
                },
                $domain
            ));
    }

    # TODO check if we still want to convert old www_include records or
    # not
    #if ($zone->{www_include} && ($zone->{www_include}->{content} == 1)) {
    #    foreach my $r (@rr) {
    #        next unless $r->{type} eq 'A';
    #        if ($r->{value} && !$r->{name}) {
    #            $packet->push(
    #                answer => $self->rr_from_hash({
    #                        ttl   => $r->{ttl},
    #                        name  => 'www',
    #                        value => $r->{value},
    #                        type  => 'A'
    #                    },
    #                    $domain
    #                ));
    #
    #        }
    #    }
    #}

    my @ns;
    foreach my $ns (@{ $zone->{nserver} }) {
        $packet->push(
            answer => $self->rr_from_hash({
                    value => $ns->{name}->{content},
                    type  => 'NS'
                },
                $domain
            ));
    }
    return $packet;
}

sub internetx_transport {
    my ($self, $d) = @_;

    $self->ix_transport(Net::DNS::Abstract::Plugins::Daemonise->new({daemonise => $d}));
    $self->ix_transport->debug($self->debug);
}

__PACKAGE__->meta->make_immutable();
