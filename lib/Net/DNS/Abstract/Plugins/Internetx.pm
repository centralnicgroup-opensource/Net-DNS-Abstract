package Net::DNS::Abstract::Plugins::Internetx;

use 5.010;
use Any::Moose 'Role';
use Net::DNS;

# ABSTRACT: wrapper interface for InternetX

with 'Net::DNS::Abstract::Plugins::Daemonise';

# Daemonise plugin has to implement ask()
requires 'ask';

=head2 axfr

Query a DNS zone via InternetX

Returns: Net::DNS::Packet object or HASHREF of parsed IX answer on error

=cut

around 'axfr' => sub {
    my ($orig, $self, $ns) = @_;

    $self->$orig($ns);

    my $hash = {
        command => 'status_zone',
        options => {
            domain    => $self->domain,
            ns        => $ns,
            interface => 'internetx',
        },
    };

    my $res = $self->ask($hash);
    my $ix_parsed = $self->_parse_ix($res->{response} || $res);

    return $ix_parsed;
};

=head2 create

Create an empty zone in the InternetX NS architecture

Returns: HASHREF of parsed IX answer

=cut

around 'create' => sub {
    my ($orig, $self, $ns) = @_;

    $self->$orig($ns);

    my $hash = {
        command => 'create_zone',
        options => {
            domain    => $self->domain,
            ns        => $ns,
            interface => 'internetx',
        },
    };

    my $res = $self->ask($hash);
    my $ix_parsed = $self->_parse_ix($res->{response} || $res);

    return $ix_parsed;
};

=head2 update

Update InternetX based on zone attribute (Net::DNS::Packet object)

Returns: HASHREF of parsed IX answer

=cut

around 'update' => sub {
    my ($orig, $self, $zone, $ns) = @_;

    $self->$orig($zone);

    return unless ($self->zone->authority || $self->zone->answer);

    my $hash = {
        command => 'update_zone',
        options => $self->from_net_dns,
    };
    $hash->{options}->{interface} = 'internetx';

    # overwrite NS from zone if given
    $hash->{options}->{ns} = $ns if ($ns and (ref $ns eq 'ARRAY'));

    my $res = $self->ask($hash);
    my $ix_parsed = $self->_parse_ix($res->{response} || $res);

    return $ix_parsed;
};

=head2 delete

Delete a zone in the InternetX NS architecture

Returns: HASHREF of parsed IX answer

=cut

around 'delete' => sub {
    my ($orig, $self, $ns) = @_;

    $self->$orig($ns);

    my $hash = {
        command => 'delete_zone',
        options => {
            domain    => $self->domain,
            ns        => $ns,
            interface => 'internetx',
        },
    };
    my $res = $self->ask($hash);
    my $ix_parsed = $self->_parse_ix($res->{response} || $res);

    return $ix_parsed;
};

=head2 _parse_ix

Parse a raw IX answer into a Net::DNS::Packet object.

Returns: Net::DNS::Packet object when zone was delivered successfully or
HASHREF of IX answer otherwise

  TODO: this should be error handling as Net::DNS expects it!

=cut

sub _parse_ix {
    my ($self, $data) = @_;

    given ($data->{code}) {
        when (/^N/) { $data->{status} = 'pending' }
        when (/^S/) { $data->{status} = 'success' }
        when (/^E/) { $data->{status} = 'error' }
    }

    # TODO this should be error handling as Net::DNS expects it!
    return { error => $data } unless $data->{status} eq 'success';
    my $zone = $data->{data}->{zone};
    return $data unless $zone;

    $self->domain($zone->{name}->{content});
    $self->zone(Net::DNS::Packet->new($self->domain, 'AXFR'));

    # add SOA first
    $self->add_rr(
        answer => {
            type    => 'SOA',
            name    => '',
            serial  => time,
            ns      => [ $zone->{nserver}->[0]->{name}->{content} ],
            email   => $zone->{soa}->{email}->{content},
            retry   => $zone->{soa}->{retry}->{content},
            refresh => $zone->{soa}->{refresh}->{content},
            expire  => $zone->{soa}->{expire}->{content},
            ttl     => $zone->{soa}->{ttl}->{content},
        });

    if (ref $zone->{rr} eq 'ARRAY') {
        foreach my $rr (@{ $zone->{rr} }) {
            $rr->{name}->{content} = ''
                unless exists $rr->{name}->{content};
            $rr->{name}->{content} = ''
                if ($rr->{name}->{content} eq $self->domain);
            $rr->{value}->{content} =~ s/\.+$//;

            $self->add_rr(
                answer => {
                    ttl => $rr->{ttl}->{content} || 3600,
                    name  => $rr->{name}->{content},
                    value => $rr->{value}->{content},
                    type  => uc($rr->{type}->{content}),
                    prio  => $rr->{pref}->{content} || undef,
                });
        }
    }
    else {
        $zone->{rr}->{name}->{content} = ''
            unless exists $zone->{rr}->{name}->{content};
        $zone->{rr}->{name}->{content} = ''
            if ($zone->{rr}->{name}->{content} eq $self->domain);
        $zone->{rr}->{value}->{content} =~ s/\.+$//;

        $self->add_rr(
            answer => {
                ttl => $zone->{rr}->{ttl}->{content} || 3600,
                name  => $zone->{rr}->{name}->{content},
                value => $zone->{rr}->{value}->{content},
                type  => uc($zone->{rr}->{type}->{content}),
                prio  => $zone->{rr}->{pref}->{content} || undef,
            });
    }

    if ($zone->{main}) {
        $self->add_rr(
            answer => {
                ttl => $zone->{main}->{ttl}->{content} || 3600,
                name  => '',
                value => $zone->{main}->{value}->{content},
                type  => 'A',
            });
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
    #                    $self->domain
    #                ));
    #
    #        }
    #    }
    #}

    my @ns;
    foreach my $ns (@{ $zone->{nserver} }) {
        $self->add_rr(
            answer => {
                value => $ns->{name}->{content},
                type  => 'NS'
            });
    }

    return $self->zone;
}

1;
