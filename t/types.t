#!/usr/bin/env perl

use Test::More;
use Test::LongString;
use Net::DNS::Packet;
use lib 'lib';

BEGIN { use_ok('Net::DNS::Abstract'); }

#subtest 'Author Tests', sub {
#    plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.'
#    if (not $ENV{TEST_AUTHOR});

my $zone = 'lnz.me. 3600   IN  SOA ns1.iwantmyname.net. info.12idn.com. (
                    1395960805  ;serial
                    86400       ;refresh
                    7200        ;retry
                    3600000     ;expire
                    3600   )    ;minimum
lnz.me. 3600    IN  A   50.112.122.158
mail.lnz.me.    3600    IN  A   62.116.130.8
www.lnz.me. 3600    IN  CNAME   lnz.me.
lnz.me. 14400   IN  NS  ns1.iwantmyname.net.
lnz.me. 14400   IN  NS  ns2.iwantmyname.net.
lnz.me. 14400   IN  NS  ns3.iwantmyname.net.
lnz.me. 14400   IN  NS  ns4.iwantmyname.net.';

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
    'domain' => 'lnz.me',
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
            'value' => 'lnz.me',
            'ttl'   => 3600,
            'name'  => 'www',
            'type'  => 'CNAME'
        }
    ],
    'soa' => {
        'email'   => 'info@12idn.com',
        'retry'   => 7200,
        'refresh' => 86400,
        'ttl'     => 3600,
        'expire'  => 3600000
    } };

my $dns = Net::DNS::Abstract->new(domain => 'lnz.me');
isa_ok($dns, 'Net::DNS::Abstract', "created Net::DNS::Abstract object");

my $b = $dns->zone(Net::DNS::Packet->new);
ok($b, "loaded empty Net::DNS::Packet as zone");
my $c = $dns->zone($zone);
ok($c, "loaded zonefile as zone");

# test zonefile import
my $dns2 = Net::DNS::Abstract->new(domain => 'lnz.me');
my $d = $dns2->zone($zone);
ok($d, "loaded zonefile as zone");
is_string_nows($dns, $zone, "round trip the zonefile");

# test stringification
is($dns, $dns2, "compare two DNS zones");
my $dns_append = $dns . 'some random string here';
isnt($dns, $dns_append, "compare two DNS zones for inequality");

# test hash export
my $hash = $dns->to_hash;
ok($hash, "exported hash from NDA");
is_deeply($hash, $zone_hash, "compare hash representation of zone");

# test hash import
my $dns3 = Net::DNS::Abstract->new(domain => 'lnz.me');
my $e = $dns3->zone($zone_hash);
ok($e, "loaded zone hash as zone");
is($dns, $dns3, "compare two DNS zones");

# test Net::DNS import
my $dns4 = Net::DNS::Abstract->new(domain => 'lnz.me');
my $f = $dns4->zone($e);
ok($f, "loaded NDA zone as zone");
is($dns, $dns4, "compare two DNS zones");

done_testing();
