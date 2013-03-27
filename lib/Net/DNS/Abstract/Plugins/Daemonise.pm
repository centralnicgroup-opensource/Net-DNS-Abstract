package Net::DNS::Abstract::Plugins::Daemonise;

use 5.010;
use Any::Moose;
use Data::Dumper;

extends 'Net::DNS::Abstract';

has 'daemonise' => (
    is      => 'rw',
    default => sub { },
);


=head2 ask

Generic interface to Daemoniser to push messages into a RabbitMQ
endpoint in a standardised way.

=cut

sub ask {
    my ($self, $hash) = @_;

    print STDERR Dumper($self->daemonise);
    if (!$hash->{options}->{interface}) {
        $self->daemonise->log("No Backend interface defined!");
        return;
    }
    my $frame = {
        meta => {
            platform => $self->platform,
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
