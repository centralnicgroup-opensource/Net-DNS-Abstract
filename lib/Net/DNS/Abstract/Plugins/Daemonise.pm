package Net::DNS::Abstract::Plugins::Daemonise;

use Modern::Perl;

use Any::Moose 'Role';

# ABSTRACT: interface to Daemonise

=head1 SYNOPSIS

Net::DNS::Abstract plugin to communicate with a Daemonise backend using RabbitMQ
endpoint in a generalized way.

=head1 ATTRIBUTES

=head2 transport

transport layer object, has to be a Daemonise object.

=cut

has 'transport' => (
    is       => 'rw',
    isa      => 'Daemonise',
    required => 1,
);

=head2 platform

Daemonise platform variable

default: iwmn

=cut

has 'platform' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'iwmn' },
);

=head1 SUBROUTINES/METHODS

=head2 daemonise

Alias to access 'transport' attribute for understandability

=cut

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
