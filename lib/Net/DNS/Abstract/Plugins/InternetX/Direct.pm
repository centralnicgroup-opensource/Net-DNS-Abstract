package Net::DNS::Abstract::Plugins::InternetX::Direct;

use 5.010;
use Any::Moose;
use Net::DNS;
use API::InternetX;

extends 'Net::DNS::Abstract';

has 'ix_login' => (
    is      => 'rw',
    default => sub { },
    lazy    => 1,
);

=head2 ask

Ask IX directly via API::InternetX

=cut

sub ask {
    my ($self, $domain, $ns) = @_;

    my $res = API::InternetX::talk({
            command => 'status_zone',
            options => {
                login => $self->ix_login,
                domain => $domain,
                ns     => $ns        # needs to be an array of name servers
            } });
    given ($res->{code}) {
        when (/^N/) { $res->{status} = 'pending' }
        when (/^S/) { $res->{status} = 'success' }
        when (/^E/) { $res->{status} = 'error' }
    }

    # TODO add retry here
    return $res;
}

__PACKAGE__->meta->make_immutable();
