package Net::DNS::Abstract::Plugins::Hexonet;

use 5.010;
use Any::Moose 'Role';

# ABSTRACT: interface to Hexonet

=head2 axfr

Query a DNS zone via Hexonet

=cut

around 'axfr' => sub {
    my ($orig, $self, $ns) = @_;

    $self->$orig($ns);

    my $zone = {
        domain    => $self->domain,
        interface => 'hexonet',
    };

    return $zone;
};

1;
