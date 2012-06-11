package Net::DNS::Abstract::Plugins::Cached;

use 5.010;
use Any::Moose;
use True::Truth;
use Net::DNS;

extends 'Net::DNS::Abstract';

has 'truth' => (
    is      => 'ro',
    isa     => 'True::Truth',
    default => sub{ True::Truth->new() },
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
    my($self, $domain) = @_;

    my $truth = $self->truth->get_true_truth($domain);
    my @rr;
    foreach my $rr (@{$truth->{dns}->{rr}}){
        push(@rr, Net::DNS::RR->new($rr));
    }

    $truth->{dns}->{rr} = \@rr;
    return $truth->{dns};
}

__PACKAGE__->meta->make_immutable();
