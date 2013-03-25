package Net::DNS::Abstract::Plugins::Daemonise;

use 5.010;
use Any::Moose;

extends 'Net::DNS::Abstract';

has 'daemonise' => (
    is      => 'rw',
    isa    => 'Daemonise',
    default => sub { },
);


=head2 ask

Generic interface to Daemoniser to push messages into a RabbitMQ
endpoint in a standardised way.

=cut

sub ask {
    my ($self, $hash) = @_;

    if (!$hash->{options}->{interface}) {
        $self->daemonise->log("No Backend interface defined!");
        return;
    }
    my $frame = {
        meta => {
            platform => $self->damonise_platform,
            lang     => 'en',
        },
        data => $hash,
    };
    my $q = 'interface.' . $hash->{options}->{interface};
    my $res = $self->daemonise->queue($q, $frame);

    # TODO add retry here
    return $res;
}

__PACKAGE__->meta->make_immutable();
