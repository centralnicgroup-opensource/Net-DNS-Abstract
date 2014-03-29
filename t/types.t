#!/usr/bin/perl

use Test::More;
use Test::LongString;
use Net::DNS::Packet;
use lib 'lib';

BEGIN { use_ok('Net::DNS::Abstract'); }

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

subtest 'Author Tests', sub {
    plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.'
        if (not $ENV{TEST_AUTHOR});
    my $dns = Net::DNS::Abstract->new(domain => 'lnz.me');
    isa_ok($dns, 'Net::DNS::Abstract', "created Net::DNS::Abstract object");

    my $b = $dns->zone(Net::DNS::Packet->new);
    ok($b, "loaded empty Net::DNS::Packet as zone");
    my $c = $dns->zone($zone);
    ok($c, "loaded zonefile as zone");
    my $dns2 = Net::DNS::Abstract->new(domain => 'lnz.me');
    my $d = $dns2->zone($zone);
    is_string_nows($dns, $zone, "round trip the zonefile");
    is($dns, $dns2, "compare two DNS zones");
};

done_testing();
