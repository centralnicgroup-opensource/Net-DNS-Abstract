package Net::DNS::Abstract::Plugins::Cached;

use 5.010;
use Any::Moose;
use True::Truth;
use Net::DNS::Update;
use Data::Dumper;

extends 'Net::DNS::Abstract';

has 'truth' => (
    is      => 'ro',
    isa     => 'True::Truth',
    default => sub { True::Truth->new() },
    lazy    => 1,
);

=head2 register

Register in the Net::DNS dispatch table for backend calls

=cut

sub provides {
    my ($self) = @_;

    return { Cached => { axfr => \&status_zone } };
}

=head2 status_zone

Query a DNS zone via InternetX

=cut

sub status_zone {
    my ($self, $domain) = @_;

    my $truth = $self->truth->get_true_truth($domain);
    my $dns = Net::DNS::Update->new($domain, 'IN');

    print Dumper($truth->{dns});
    $dns->push(
        update => Net::DNS::RR->new(
            name    => $domain,
            retry   => $truth->{dns}->{soa}->{retry},
            rname   => $truth->{dns}->{soa}->{email},
            refresh => $truth->{dns}->{soa}->{refresh},
            ttl     => $truth->{dns}->{soa}->{ttl},
            expire  => $truth->{dns}->{soa}->{expire},
            type    => 'SOA',
        ));
    foreach my $rr (@{ $truth->{dns}->{rr} }) {
        given ($rr->{type}) {
            when (/^a*$/i) {
                $dns->push(
                    update => Net::DNS::RR->new(
                        name => (
                            $rr->{name} ? $rr->{name} . '.' . $domain : $domain
                        ),
                        class   => 'IN',
                        ttl     => $rr->{ttl},
                        type    => $rr->{type},
                        address => $rr->{value},
                    ));
            }
            when (/^cname$/i) {
                $dns->push(
                    update => Net::DNS::RR->new(
                        name => (
                            $rr->{name} ? $rr->{name} . '.' . $domain : $domain
                        ),
                        class => 'IN',
                        ttl   => $rr->{ttl},
                        type  => $rr->{type},
                        cname => $rr->{value},
                    ));
            }
            when (/^mx$/i) {
                $dns->push(
                    update => Net::DNS::RR->new(
                        name => (
                            $rr->{name} ? $rr->{name} . '.' . $domain : $domain
                        ),
                        class    => 'IN',
                        ttl      => $rr->{ttl},
                        type     => $rr->{type},
                        exchange => $rr->{value},
                        prio     => $rr->{prio},
                    ));
            }
            when (/^srv$/i) {
                my ($weight, $port, $target) = split(/\s/, $rr->{value}, 3);
                $dns->push(
                    update => Net::DNS::RR->new(
                        name => (
                            $rr->{name} ? $rr->{name} . '.' . $domain : $domain
                        ),
                        class  => 'IN',
                        ttl    => $rr->{ttl},
                        type   => $rr->{type},
                        target => $target,
                        weight => $weight,
                        port   => $port,
                        prio   => $rr->{prio},
                    ));
            }
            when (/^txt$/i) {
                $dns->push(
                    update => Net::DNS::RR->new(
                        name => (
                            $rr->{name} ? $rr->{name} . '.' . $domain : $domain
                        ),
                        class   => 'IN',
                        ttl     => $rr->{ttl},
                        type    => $rr->{type},
                        txtdata => $rr->{value},
                    ));
            }
        }
    }
    foreach my $rr (@{ $truth->{dns}->{ns} }) {
        $dns->push(
            update => Net::DNS::RR->new(
                name    => $rr->{name},
                class   => 'IN',
                type    => 'NS',
                address => $rr->{ip} || undef,
            ));
    }

    print Dumper($dns);
    return $dns;
}

__PACKAGE__->meta->make_immutable();
