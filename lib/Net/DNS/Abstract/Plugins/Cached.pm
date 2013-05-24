package Net::DNS::Abstract::Plugins::Cached;

use 5.010;
use Any::Moose 'Role';
use True::Truth;
use Data::Dump 'dump';

# ABSTRACT: interface to True::Truth

has 'truth' => (
    is      => 'ro',
    isa     => 'True::Truth',
    default => sub { True::Truth->new() },
    lazy    => 1,
);

=head2 axfr

Query a DNS zone from the Cache

Returns: Net::DNS::Packet object or undef on error

=cut

around 'axfr' => sub {
    my ($orig, $self, $ns) = @_;

    $self->$orig($ns);

    my $truth = $self->truth->get_true_truth($self->domain);
    $self->zone($self->our_to_net_dns($truth->{dns}));

    $self->log($self->zone->string) if $self->debug;

    return $self->zone;
};

=head2 update

Update a DNS zone in the Cache

Returns: our normalized zone format or undef on error

=cut

around 'update' => sub {
    my ($orig, $self, $zone) = @_;

    $self->$orig($zone);

    $zone = $self->from_net_dns;

    # TODO: write zone back into true::truth cache?

    $self->log(dump($zone)) if $self->debug;

    return $zone;
};

1;
