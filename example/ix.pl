#!/bin/perl -Ilib

use 5.010;
use lib '.';
use Net::DNS::Abstract;
use Net::DNS::Abstract::Plugins::InternetX::Direct;
use Data::Dumper;
use Daemonise;

my $dns    = Net::DNS::Abstract->new(debug => 1);
my $zone_file = ';; HEADER SECTION
;; id = 50262
;; qr = 0    opcode = UPDATE    rcode = NOERROR
;; zocount = 0  prcount = 0  upcount = 9  adcount = 0

;; ZONE SECTION (1 record)
;; domain.tld.      IN      SOA

;; PREREQUISITE SECTION (0 records)

;; UPDATE SECTION (9 records)
domain.tld. 86400   IN      SOA     ns1.iwantmyname.net. email\@domain.tld. (
                                        1364440813      ; Serial
                                        0       ; Refresh
                                        72003600000     ; Retry
                                        0       ; Expire
                                         )      ; Minimum TTL
domain.tld. 3600    IN      A       50.112.122.158
bla.domain.tld.     3600    IN      A       118.93.40.93
blubb.domain.tld.   3600    IN      A       3.5.6.9
mail.domain.tld.    3600    IN      A       62.116.130.8
domain.tld. 14400   IN      NS      ns1.iwantmyname.net.
domain.tld. 14400   IN      NS      ns2.iwantmyname.net.
domain.tld. 14400   IN      NS      ns3.iwantmyname.net.
domain.tld. 14400   IN      NS      ns4.iwantmyname.net.

;; ADDITIONAL SECTION (0 records)';

my $zone = $dns->to_net_dns({
    'ns' => [
        { 'name' => 'ns1.iwantmyname.net' },
        { 'name' => 'ns2.iwantmyname.net' },
        { 'name' => 'ns3.iwantmyname.net' },
        { 'name' => 'ns4.iwantmyname.net' }
    ],
    'domain' => 'domain.tld',
    'soa'    => {
        'retry'   => '7200',
        'email'   => 'email\\@domain.tld',
        'refresh' => '86400',
        'ttl'     => '0',
        'expire'  => '3600000'
    },
    'rr' => [ {
            'ttl'   => '3600',
            'value' => '50.112.122.158',
            'name'  => undef,
            'type'  => 'A'
        }, {
            'ttl'   => '3600',
            'value' => '118.93.40.93',
            'name'  => 'bla',
            'type'  => 'A'
        }, {
            'ttl'   => '3600',
            'value' => '3.5.6.9',
            'name'  => 'blubb',
            'type'  => 'A'
        }, {
            'ttl'   => '3600',
            'value' => '62.116.130.8',
            'name'  => 'mail',
            'type'  => 'A'
        },
    ] });

my $ix_ref = Daemonise->new();
#my $query  = {
#    domain              => 'domain.tld',
#    interface           => 'internetx',
#    ns                  => [ 'ns1.iwantmyname.net', 'ns2.iwantmynme.net' ],
#    internetx_transport => $ix_ref,
#};

my $query = {
    zone => $zone_file,
    interface => 'internetx',
    internetx_transport => $ix_ref,
};

#my $res = $dns->axfr($query);
my $res = $dns->update($query);

say "\n###### Got Answer for domain.tld ########";

print Dumper($res);
say $dns->to_string($zone);
