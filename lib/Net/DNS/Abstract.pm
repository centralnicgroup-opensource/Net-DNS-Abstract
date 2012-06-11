package Net::DNS::Abstract;

use 5.010;
use Any::Moose;
use Module::Load;
use Data::Dumper;

=head1 NAME

Net::DNS::Abstract - Net::DNS interface to several DNS backends via API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

has 'debug' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    lazy    => 1,
);

has 'registry' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);


=head1 SYNOPSIS

Net::DNS is the de-facto standard and battle tested perl DNS
implementation. Unfortunately we don't intercat with DNS via DNS
protocols but via 3rd party abstration layers that have all sorts of
quirks. We try to provide one unified interface here.

=head1 SUBROUTINES/METHODS

=head2 axfr

Do a zone transfer (actually poll a zone from a 3rd party provider) and
return a list of Net::DNS::RR objects. Instead of a list of nameservers
we need a backend identifyer that we have a API plugin for.

    axfr({ domain => 'example.com', interface => 'InternetX'})

=cut

sub axfr {
    my($self, $params) = @_;

    my $plugin = $self->load_plugin($params->{interface});
    my $ref = $self->registry->{$params->{interface}}->{axfr};
        
    my $zone = $plugin->$ref($params->{domain});
    return $zone;
}


=head2 load_plugin

Loads a Plugin for Net::DNS::Abstract

=cut

sub load_plugin {
    my($self, $plugin) = @_;

    my $module = 'Net::DNS::Abstract::Plugins::'.$plugin;
    load $module;
    my $new_mod =  $module->new();
    $self->register($new_mod->provides());
    print Dumper("load", $self->registry)
        if $self->debug();
    return $new_mod;
}


=head2 register

Registers a plugin in the internal registry (with all the callbacks we
need for dispatching).

=cut

sub register {
    my($self, $params) = @_;

    foreach my $key (keys %{$params}){
        $self->registry->{$key} = $params->{$key};
    }
    return;
}

=head1 AUTHOR

Lenz Gschwendtner, C<< <norbu09 at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-dns-abstract at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-DNS-Abstract>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::DNS::Abstract


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-DNS-Abstract>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-DNS-Abstract>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-DNS-Abstract>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-DNS-Abstract/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Lenz Gschwendtner.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

__PACKAGE__->meta->make_immutable();
