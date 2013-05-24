package Net::DNS::Abstract::Plugins::Daemonise;

use 5.010;
use Any::Moose 'Role';

# ABSTRACT: interface to Daemonise

has 'transport' => (
    is       => 'rw',
    isa      => 'Daemonise',
    required => 1,
);

=head2 platform

=cut

has 'platform' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'iwmn' },
);

# alias 'daemonise' to 'transport' for understandability
sub daemonise {
    my ($self) = @_;
    return $self->transport;
}

=head2 ask

Generic interface to Daemonise to push messages into a RabbitMQ endpoint in a
standardised way.

=cut

sub ask {
    my ($self, $hash) = @_;

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

    return $res;
}

1;
