#!/usr/bin/perl

use Test::More;
use Test::LongString;
use Net::DNS::Packet;
use lib 'lib';
use Data::Dumper;

BEGIN { use_ok('Net::DNS::Abstract'); }

my $zone = 'domain.tld. 3600   IN  SOA ns1.iwantmyname.net. email.domain.tld. (
                    1395960805  ;serial
                    86400       ;refresh
                    7200        ;retry
                    3600000     ;expire
                    3600   )    ;minimum
domain.tld. 3600    IN  A   50.112.122.158
mail.domain.tld.    3600    IN  A   62.116.130.8
www.domain.tld. 3600    IN  CNAME   domain.tld.
domain.tld. 14400   IN  NS  ns1.iwantmyname.net.
domain.tld. 14400   IN  NS  ns2.iwantmyname.net.
domain.tld. 14400   IN  NS  ns3.iwantmyname.net.
domain.tld. 14400   IN  NS  ns4.iwantmyname.net.';

my $zone_hash = {
    'ns' => [ {
            'ttl'  => 14400,
            'name' => 'ns1.iwantmyname.net'
        }, {
            'ttl'  => 14400,
            'name' => 'ns2.iwantmyname.net'
        }, {
            'ttl'  => 14400,
            'name' => 'ns3.iwantmyname.net'
        }, {
            'ttl'  => 14400,
            'name' => 'ns4.iwantmyname.net'
        }
    ],
    'domain' => 'domain.tld',
    'rr'     => [ {
            'value' => '50.112.122.158',
            'ttl'   => 3600,
            'name'  => undef,
            'type'  => 'A'
        }, {
            'value' => '62.116.130.8',
            'ttl'   => 3600,
            'name'  => 'mail',
            'type'  => 'A'
        }, {
            'value' => 'domain.tld',
            'ttl'   => 3600,
            'name'  => 'www',
            'type'  => 'CNAME'
        }
    ],
    'soa' => {
        'email'   => 'email@domain.tld',
        'retry'   => 7200,
        'refresh' => 86400,
        'ttl'     => 3600,
        'expire'  => 3600000
    } };

my $dns = Net::DNS::Abstract->new(domain => 'domain.tld');
isa_ok($dns, 'Net::DNS::Abstract', "created Net::DNS::Abstract object");

my $b = $dns->zone(Net::DNS::Packet->new);
ok($b, "loaded empty Net::DNS::Packet as zone");
my $c = $dns->zone($zone);
ok($c, "loaded zonefile as zone");

my $dns2 = Net::DNS::Abstract->new(domain => 'domain.tld');
my $d = $dns2->zone($zone);
is_string_nows($dns, $zone, "round trip the zonefile");
is($dns, $dns2, "compare two DNS zones");

my $hash = $dns->to_hash;
is_deeply($hash, $zone_hash, "compare hash representation of zone");

my $dns3 = Net::DNS::Abstract->new(domain => 'domain.tld');
my $e = $dns3->zone($zone_hash);
is($dns, $dns3, "compare two DNS zones");

done_testing();
