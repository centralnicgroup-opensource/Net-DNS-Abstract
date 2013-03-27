package Net::DNS::Abstract;

use 5.010;
use Any::Moose;
use Module::Load;
use Net::DNS;
use Net::DNS::Packet;
use Carp;
use Data::Dumper;

=head1 NAME

Net::DNS::Abstract - Net::DNS interface to several DNS backends via API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

has 'debug' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
    lazy    => 1,
);

has 'registry' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'platform' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'iwmn' },
);

=head1 SYNOPSIS

Net::DNS is the de-facto standard and battle tested perl DNS
implementation. Unfortunately we don't intercat with DNS via DNS
protocols but via 3rd party abstration layers that have all sorts of
quirks. We try to provide one unified interface here.

=head1 SUBROUTINES/METHODS

=head2 axfr

Do a zone transfer (actually poll a zone from a 3rd party provider) and
return a list of Net::DNS::RR objects. Additional to a list of nameservers
we need a backend identifyer that we have a API plugin for.

    axfr({ 
        domain => 'example.com', 
        interface => 'InternetX', 
        ns => ['ns1.provider.net']
    })

=cut

sub axfr {
    my ($self, $params) = @_;

    my $plugin = $self->load_plugin($params->{interface}, $params);
    my $ref = $self->registry->{ $params->{interface} }->{axfr};

    my $zone = $plugin->$ref($params->{domain}, $params->{ns});
    return $zone;
}

=head2 update

Update a DNS zone via the respective backend plugin. This function takes
a Net::DNS update object and pushes it through to the backend plugin to
process it.

=cut

sub update {
    my ($self, $dns, $interface) = @_;
    carp "No Plugin defined" unless $interface;

    my $plugin = $self->load_plugin($interface);
    my $ref    = $self->registry->{$interface}->{update};

    my $zone = $plugin->$ref($dns);
    return $zone;
}

=head2 to_net_dns

Converts a zone from our generic representation to Net::DNS format.

=cut

sub to_net_dns {
    my ($self, $zone) = @_;

    my $dns = Net::DNS::Update->new($zone->{domain}, 'IN');

    print Dumper($zone) if $self->debug();

    # TODO this SOA record needs cleanup and debugging!
    $dns->push(
        update => rr_add(
                  $zone->{domain} . ' '
                . $zone->{soa}->{ttl}
                . ' IN SOA '
                . $zone->{ns}->[0]->{name} . ' '
                . $zone->{soa}->{email} . ' '
                . time . ' '
                . $zone->{soa}->{ttl} . ' '
                . $zone->{soa}->{retry}
                . $zone->{soa}->{expire} . ' '
                . $zone->{soa}->{ttl}));

    # convert RR section
    foreach my $rr (@{ $zone->{rr} }) {
        $self->add_rr_update($dns, $rr);
    }

    # convert NS section
    foreach my $rr (@{ $zone->{ns} }) {
        $dns->push(
            update => Net::DNS::RR->new(
                name    => $zone->{domain},
                class   => 'IN',
                type    => 'NS',
                ttl     => $rr->{ttl} || 14400,
                nsdname => $rr->{name},
            ));
    }

    print Dumper($dns) if $self->debug();
    return $dns;
}

=head2 add_rr

Adds a RR hash to a Net::DNS object. Also converts our standardized hash
into a Net::DNS::RR object.

=cut

sub add_rr_update {
    my ($self, $dns, $rr) = @_;

    return $dns->push(
        update => $self->rr_from_hash($rr, ($dns->question)[0]->qname));
}

=head2 rr_from_hash

Create a Net::DNS::RR object from a hash

=cut

sub rr_from_hash {
    my ($self, $rr, $domain) = @_;

    print Dumper($rr, $domain) if $self->debug;
    # TODO add SOA record support
    given ($rr->{type}) {
        when (/^a{1,4}$/i) {
            return Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    address => $rr->{value},
                );
        }
        when (/^cname$/i) {
            return Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class => 'IN',
                    ttl   => $rr->{ttl} || 3600,
                    type  => $rr->{type},
                    cname => $rr->{value},
                );
        }
        when (/^mx$/i) {
            return Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class    => 'IN',
                    ttl      => $rr->{ttl} || 14400,
                    type     => $rr->{type},
                    exchange => $rr->{value},
                    prio     => $rr->{prio},
                );
        }
        when (/^srv$/i) {
            my ($weight, $port, $target) = split(/\s/, $rr->{value}, 3);
            return Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class  => 'IN',
                    ttl    => $rr->{ttl} || 14400,
                    type   => $rr->{type},
                    target => $target,
                    weight => $weight,
                    port   => $port,
                    prio   => $rr->{prio},
                );
        }

        # FIXME check for 255 char limit and split it up into
        # several records if apropriate
        when (/^txt$/i) {
            return Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    txtdata => $rr->{value},
                );
        }
        when (/^ns$/i) {
            return Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 14400,
                    type    => $rr->{type},
                    nsdname => $rr->{value},
                );
        }
        when (/^soa$/i) {
            return Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $domain
                        : $domain
                    ),
                    mname   => $rr->{ns}->[0],
                    rname   => $rr->{email},
                    retry   => $rr->{retry},
                    refresh => $rr->{refresh},
                    expire  => $rr->{expire},
                    minimum => $rr->{ttl},
                    nsdname => $rr->{value},
                    type    => $rr->{type},
                );
        }
    }
}

=head2 from_net_dns

Convert a Net::DNS object into our normalized format

=cut

sub from_net_dns {
    my ($self, $dns) = @_;

    my $zone;
    #print Dumper($zone) if $self->debug;
    my $domain = ($dns->question)[0]->qname;
    foreach my $rr (@{ $dns->{authority} }) {
        given ($rr->type) {
            my $name = $rr->name;
            $name =~ s/\.?$domain$//;
            when ('SOA') {
                $zone->{soa} = {
                    'retry'   => $rr->retry,
                    'email'   => $rr->rname,
                    'refresh' => $rr->refresh,
                    'ttl'     => $rr->ttl,
                    'expire'  => $rr->expire,
                };
                $zone->{domain} = $rr->name;
            }
            when ('NS') {
                push(@{ $zone->{ns} }, { name => $rr->nsdname });
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
                        prio => $rr->prio,
                        value => $rr->exchange,
                    });
            }
            when ('SRV') {
                push(
                    @{ $zone->{rr} }, {
                        name => $name || undef,
                        ttl  => $rr->ttl,
                        type => $rr->type,
                        prio => $rr->prio,
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

=head2 to_string

Stringify a Net::DNS object

=cut

sub to_string {
    my ($self, $dns) = @_;

    return $dns->string;
}

=head2 load_plugin

Loads a Plugin for Net::DNS::Abstract

=cut

sub load_plugin {
    my ($self, $plugin, $params) = @_;

    my $module = 'Net::DNS::Abstract::Plugins::' . ucfirst($plugin);
    load $module;
    my $new_mod = $module->new();
    $self->register($new_mod->provides());
    foreach my $key (keys %{$params}){
        next unless $key =~ m{$plugin};
        eval{$new_mod->$key($params->{$key})};
        warn $@ if $@;
    }
    print Dumper("load", $self->registry)
        if $self->debug();
    return $new_mod;
}

=head2 register

Registers a plugin in the internal registry (with all the callbacks we
need for dispatching).

=cut

sub register {
    my ($self, $params) = @_;

    foreach my $key (keys %{$params}) {
        $self->registry->{$key} = $params->{$key};
    }
    return;
}

=head1 AUTHOR

Lenz Gschwendtner, C<< <norbu09 at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-dns-abstract at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-DNS-Abstract>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::DNS::Abstract


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-DNS-Abstract>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-DNS-Abstract>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-DNS-Abstract>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-DNS-Abstract/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Lenz Gschwendtner.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

__PACKAGE__->meta->make_immutable();
