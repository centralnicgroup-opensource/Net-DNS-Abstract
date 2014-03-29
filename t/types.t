#!/usr/bin/perl

use Test::More;
use Test::LongString;
use Net::DNS::Packet;
use lib 'lib';

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

subtest 'Author Tests', sub {
    plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.'
        if (not $ENV{TEST_AUTHOR});
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
};

done_testing();
