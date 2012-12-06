package Net::DNS::Abstract::Plugins::Cached;

use 5.010;
use Any::Moose;
use True::Truth;
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

    return { Cached => { axfr => \&status_zone, update => \&update_zone } };
}

=head2 status_zone

Query a DNS zone from the Cache

=cut

sub status_zone {
    my ($self, $domain) = @_;

    my $truth = $self->truth->get_true_truth($domain);
    my $dns = $self->to_net_dns($truth->{dns});
    print $dns->string;
    return $dns;
}

=head2 update_zone

Update a DNS zone in the Cache

=cut

sub update_zone {
    my($self, $dns) = @_;

    my $zone = $self->from_net_dns($dns);
    print Dumper($zone);
    return $zone;
}

__PACKAGE__->meta->make_immutable();
