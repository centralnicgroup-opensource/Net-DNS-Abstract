package Net::DNS::Abstract::Plugins::Internetx;

use Modern::Perl;

use Mouse::Role;
use Net::DNS;
use Try::Tiny;
use Data::Printer;

use lib 'lib';
use Net::DNS::Abstract::RR;

use experimental 'smartmatch';

# ABSTRACT: wrapper interface for InternetX

with 'Net::DNS::Abstract::Plugins::Daemonise';

=head1 SYNOPSIS

Net::DNS::Abstract plugin for talking to InternetX using a Daemonise object as
transport layer

=head1 REQUIRED METHODS

=head2 ask

Daemonise plugin has to implement ask()

=cut

requires 'ask';

=head1 METHOD MODIFIERS

=head2 axfr

Query a DNS zone at InternetX

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
        options => $self->to_hash,
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
    my $nda_zone = Net::DNS::Packet->new($self->domain, 'AXFR');

    my $nda_rr = Net::DNS::Abstract::RR->new(domain => $self->domain);

    # add SOA record first
    try {
        $nda_zone = $nda_rr->add(
            $nda_zone,
            answer => {
                type    => 'SOA',
                name    => '',
                serial  => time,
                ns      => [ $zone->{nserver}->[0]->{name}->{content} ],
                email   => $zone->{soa}->{email}->{content},
                retry   => $zone->{soa}->{retry}->{content},
                refresh => $zone->{soa}->{refresh}->{content},
                expire  => $zone->{soa}->{expire}->{content},
                minimum => $zone->{soa}->{ttl}->{content},
            });
    }
    catch {
        warn "Could not add SOA record: " . p($zone);
    };

    # add NS records
    my @ns;
    foreach my $ns (@{ $zone->{nserver} }) {
        my $tmp_nda_zone;
        try {
            $tmp_nda_zone = $nda_rr->add(
                $nda_zone,
                answer => {
                    value => $ns->{name}->{content},
                    type  => 'NS',
                });
        }
        catch {
            warn "Could not add NS " . p($ns);
        };
        $nda_zone = $tmp_nda_zone if $tmp_nda_zone;
    }

    # handle IX "main" section (a.k.a. single A record on root domain)
    if (exists $zone->{main} and ref $zone->{main} eq 'HASH') {
        my $tmp_nda_zone;
        try {
            $tmp_nda_zone = $nda_rr->add(
                $nda_zone,
                answer => {
                    ttl => $zone->{main}->{ttl}->{content} || 3600,
                    name  => '',
                    value => $zone->{main}->{value}->{content},
                    type  => 'A',
                });
        }
        catch {
            warn "Could not add RR " . p($zone->{main});
        };

        $nda_zone = $tmp_nda_zone if $tmp_nda_zone;
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

    # add optional extra RRs
    if (exists $zone->{rr}) {
        if (ref $zone->{rr} eq 'ARRAY') {
            foreach my $rr (@{ $zone->{rr} }) {
                $rr->{name}->{content} = ''
                    unless exists $rr->{name}->{content};
                $rr->{name}->{content} = ''
                    if ($rr->{name}->{content} eq $self->domain);
                $rr->{value}->{content} =~ s/\.+$//;

                my $tmp_nda_zone;
                try {
                    $tmp_nda_zone = $nda_rr->add(
                        $nda_zone,
                        answer => {
                            ttl => $rr->{ttl}->{content} || 3600,
                            name  => $rr->{name}->{content},
                            value => $rr->{value}->{content},
                            type  => uc($rr->{type}->{content}),
                            prio  => $rr->{pref}->{content} || undef,
                        });
                }
                catch {
                    warn "Could not add RR " . p($rr);
                };
                $nda_zone = $tmp_nda_zone if $tmp_nda_zone;
            }
        }
        else {
            $zone->{rr}->{name}->{content} = ''
                unless exists $zone->{rr}->{name}->{content};
            $zone->{rr}->{name}->{content} = ''
                if ($zone->{rr}->{name}->{content} eq $self->domain);
            $zone->{rr}->{value}->{content} =~ s/\.+$//
                if exists $zone->{rr}->{value}->{content};

            my $tmp_nda_zone;
            try {
                $tmp_nda_zone = $nda_rr->add(
                    $nda_zone,
                    answer => {
                        ttl => $zone->{rr}->{ttl}->{content} || 3600,
                        name  => $zone->{rr}->{name}->{content},
                        value => $zone->{rr}->{value}->{content},
                        type  => uc($zone->{rr}->{type}->{content}),
                        prio  => $zone->{rr}->{pref}->{content} || undef,
                    });
            }
            catch {
                warn "Could not add RR " . p($zone);
            };

            $nda_zone = $tmp_nda_zone if $tmp_nda_zone;
        }
    }

    $self->zone($nda_zone);

    return $self->zone;
}

1;
