package Net::DNS::Abstract::RR;

use Modern::Perl;

use Mouse;
use experimental 'smartmatch';
use Text::Wrap 'wrap';

# TXT records can be a max of 255 characters, wrap at word boundaries
$Text::Wrap::columns = 253;

# ABSTRACT: Net::DNS::Abstract Resource Record methods

=head2 domain

the domain as a punycode string of the underlaying zone (required)

=cut

has 'domain' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 add

Add a Net::DNS::RR object to the zone attribute

Returns: true when successful, false otherwise

=cut

sub add {
    my ($self, $zone, $section, $rr) = @_;

    #$self->log('add_arr(): ' . dump($section, $rr)) if $self->debug;

    return
        unless $section =~
        m/^(header|question|answer|pre|prereq|authority|update|additional)$/;

    given ($rr->{type}) {
        when (/^SOA$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    mname  => $rr->{ns}->[0] || 'ns1.iwantmyname.net',
                    rname  => $rr->{email}   || 'hostmaster@iwantmyname.com',
                    serial => $rr->{serial}  || time,
                    retry  => $rr->{retry},
                    refresh => $rr->{refresh},
                    expire  => $rr->{expire},
                    minimum => $rr->{minimum},
                    type    => $rr->{type},
                ));
            return $zone;
        }
        when (/^A{1,4}$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    address => $rr->{value},
                ));
            return $zone;
        }
        when (/^CNAME$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class => 'IN',
                    ttl   => $rr->{ttl} || 3600,
                    type  => $rr->{type},
                    cname => $rr->{value},
                ));
            return $zone;
        }
        when (/^MX$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class      => 'IN',
                    ttl        => $rr->{ttl} || 14400,
                    type       => $rr->{type},
                    exchange   => $rr->{value},
                    preference => $rr->{prio},
                ));
            return $zone;
        }
        when (/^SRV$/i) {
            my ($weight, $port, $target) = split(/\s+/, $rr->{value}, 3);

            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class    => 'IN',
                    ttl      => $rr->{ttl} || 14400,
                    type     => $rr->{type},
                    target   => $target,
                    weight   => $weight,
                    port     => $port,
                    priority => $rr->{prio},
                ));
            return $zone;
        }
        when (/^TXT$/i) {

            # split too long TXT records into multiple records on word boundary
            # limit: 253 chars
            my $txt_value = $rr->{value};

            if (length($txt_value) > 255) {

                # firt remove any double quotes previously created to prevent
                # accidental nested quotes
                $txt_value =~ s/^"//;
                $txt_value =~ s/" "/ /g;
                $txt_value =~ s/"$//;

                # then split and remerge with fresh double quotes
                my @txt = split(/\n/, wrap('', '', $txt_value));
                $txt_value = '"' . shift(@txt) . '"';
                $txt_value .= ' "' . $_ . '"' for (@txt);
            }

            # Net::DNS::RR srips leading quotes `"' because it employs
            # JSON->encode to store its values so we need to escape it
            # fixes https://github.com/ideegeo/iwmn-base/issues/1567
            $txt_value =~ s/^"/\\"/;

            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 3600,
                    type    => $rr->{type},
                    txtdata => $txt_value,
                ));
            return $zone;
        }
        when (/^NS$/i) {
            $zone->push(
                $section => Net::DNS::RR->new(
                    name => (
                          $rr->{name}
                        ? $rr->{name} . '.' . $self->domain
                        : $self->domain
                    ),
                    class   => 'IN',
                    ttl     => $rr->{ttl} || 14400,
                    type    => $rr->{type},
                    nsdname => $rr->{value} || 'ns1.iwantmyname.net',
                ));
            return $zone;
        }
        when (/^CAA$/i) {
            my ($flags, $tag, $value) = split(/\s+/, $rr->{value}, 3);

            $zone->push(
                $section => Net::DNS::RR->new(
                    name  => $rr->{name},
                    class => 'IN',
                    ttl   => $rr->{ttl} || 14400,
                    type  => $rr->{type},
                    flags => $flags,
                    tag   => $tag,
                    value => $value,
                ));
            return $zone;
        }
        default {
            warn(     'add_arr(): '
                    . $self->domain
                    . ": unsupported record type: "
                    . $rr->{type});
            return;
        }
    }

    return;
}

1;
