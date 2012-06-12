#!/usr/bin/perl

use Test::More;
use Test::Deep;
use lib 'lib';

plan qw/no_plan/;

{

    BEGIN { use_ok('Net::DNS::Abstract'); }
    my $dns = Net::DNS::Abstract->new();
    ok($dns);

    my $a = { domain => 'domain.tld', interface => 'Cached' };
    my $b = $dns->axfr($a);
    ok($b);
    cmp_deeply(
        $b, {
            domain => 'domain.tld',
            interface => 'Cached',
        },
        "check hash structure for Cached"
    );
    print Dumper $b;
    my $c = $dns->update($b, 'Cached');
    ok($c);
    cmp_deeply(
        $c, {
            domain => 'domain.tld',
            interface => 'Cached',
        },
        "check hash structure for Cached"
    );
    print Dumper $c;

}

