package Net::DNS::Abstract;

use Modern::Perl;

use Mouse;
use Module::Load;
use Net::DNS;
use Net::DNS::Packet;
use Net::DNS::ZoneFile::Fast;
use Data::Dump 'dump';

use lib 'lib';
use Net::DNS::Abstract::Types qw/Zone/;

use experimental 'smartmatch';

use overload
    '""' => sub { shift->to_string },
    'eq' => sub { shift->string_eq },
    'ne' => sub { shift->string_eq };

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
    default => sub { 0 },
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

the Net::DNS::Packet object of the underlaying zone including a subtype
to convert between formats to Net::DNS

=cut

has 'zone' => (
    is      => 'rw',
    isa     => 'Zone',
    coerce  => 1,
    default => sub { Net::DNS::Packet->new },
);

=head2 interface

defines the interface plugin to load (required)

=cut

has 'interface' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    default  => 'internal',
);

before 'new' => sub {
    my ($class, %args) = @_;

    if (exists $args{interface}) {
        push(@{ $args{preload} }, $args{interface})

            # TODO write some sanitisation stuff with internal conversions
            # of our hash into a Net::DNS structure. We need this for hash
            # -> zonefile conversions
            unless $args{interface} eq 'internal';
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

    $self->zone($zone);

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

=head2 to_string

Converts a Net::DNS object into a flat zonefile without comments and
empty lines. This is an alternative to calling $nda->string

This function returns a zonefile string

=cut

sub to_string {
    my ($self) = @_;

    # strip out comments and empty lines
    my @zone = split(/\n/, $self->zone->string);

    my $zonefile;
    foreach my $line (@zone) {
        next if $line =~ m{^$};
        next if $line =~ m{^;};
        $zonefile .= $line . "\n";
    }

    return $zonefile;
}

=head2 string_eq

Overloading endpoint for string comparison of two Net::DNS::Abstract
objects

This function returns a zonefile string

=cut

sub string_eq {
    my ($self) = @_;

    my $zone = $self->to_string;
    return unless $zone;
    return $zone =~ s{\s+}{}gmx;
}

=head2 to_hash

Convert a Net::DNS object into our normalized format

Returns: our normalized format as HASHREF or undef on error

=cut

sub to_hash {
    my ($self) = @_;

    my $domain = $self->domain;

    $self->log("to_hash(): DOMAIN: >> $domain <<");

    my @rrs = (
          $self->zone->authority
        ? $self->zone->authority
        : $self->zone->answer
    );

    $self->log("to_hash(): RRs: " . dump(@rrs));

    # initialize zone hash
    my $zone = { domain => $domain };

    foreach my $rr (@rrs) {
        $self->log("to_hash(): RR: " . ref($rr));

        my $name = $rr->name;
        $name =~ s/\.?$domain$//;
        $name = '' if $name eq '.';

        given ($rr->type) {
            when ('SOA') {
                $zone->{soa} = {
                    retry   => $rr->retry,
                    email   => $rr->rname,
                    refresh => $rr->refresh,
                    ttl     => $rr->ttl,
                    expire  => $rr->expire,
                };

                unless ($domain) {
                    $zone->{domain} = $rr->name;
                    $domain = $zone->{domain};
                    $self->domain($domain);
                }
            }
            when ('NS') {

                # if we have a NS record for the domain itself we want
                # it in $zone->{ns} if it is a delegation for a
                # subdomain we want it in the $zone->{rr} section
                if ($rr->name eq $self->domain) {
                    push(
                        @{ $zone->{ns} },
                        { name => $rr->nsdname, ttl => $rr->ttl });
                }
                else {
                    push(
                        @{ $zone->{rr} }, {
                            name => $name || undef,
                            ttl  => $rr->ttl,
                            type => $rr->type,
                            value => $rr->nsdname,
                        });
                }
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

    # sort records lexicographically by type first
    # then by number of sub records
    if ($zone->{rr}) {
        $zone->{rr} = [
            sort {
                       ($a->{type} || "") cmp($b->{type} || "")
                    || ($a->{prio} || 0) <=> ($b->{prio} || 0)
                    || ($a->{name} || "") cmp($b->{name} || "")
            } @{ $zone->{rr} } ];
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

    print STDERR __PACKAGE__ . ": $msg\n" if $self->debug;

    return;
}

=head2 sanitise_zone

Sanitise a zone. This should always be called explicitly if you think
the zone could contain duplicate records. this is normally not necessary
but converting between formats of zone representations can trigger
unwanted results like multiple NS records.

=cut

sub sanitise_zone {
    my ($self, $zone) = @_;

    my $c = 0;
    foreach my $rr (@{ $zone->{rr} }) {
        delete $zone->[$c];
    }

    return;
}

# TODO we may have to do more here like make sure all keys have the same case.
sub _check_for_dupes {
    my ($zone, $record) = @_;

    foreach my $rr (@{$zone}) {
        my $c = 0;
        foreach my $ky (keys %{$rr}) {
            $c++;
            next unless exists $record->{$ky};
            next unless uc($rr->{$ky}) eq uc($record->{$ky});
            $c--;
        }
        return 1 if $c == 0;
    }

    return;
}

1;
