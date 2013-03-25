package Net::DNS::Abstract::Plugins::Daemoniser;

use 5.010;
use Any::Moose;
use Daemonise;
use File::Basename;

extends 'Net::DNS::Abstract';

has 'daemonise_conf' => (
    is      => 'rw',
    default => sub {'/etc/d8o/hase.conf'},
    lazy    => 1,
);

has 'damonise_platform' => (
    is      => 'rw',
    default => sub {'iwmn'},
    lazy    => 1,
);

has 'daemonise_queue' => (
    is      => 'rw',
    default => sub { basename($0) =~ m/^(.*)\.\w\+$/ },
    lazy    => 1,
);

has 'daemonise' => (
    is      => 'rw',
    isa    => 'Daemonise',
    default => sub { Daemonise->new() },
    lazy    => 1,
);




=head2 BUILD

Init the Daemoniser lib with all the right things

=cut

sub BUILD {
    my $self = shift;

    $self->daemonise->config_file($self->daemonise_conf);
    $self->daemonise->configure;
    $self->daeminise->load_plugin('RabbitMQ');

}

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
