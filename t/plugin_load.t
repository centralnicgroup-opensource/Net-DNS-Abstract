#!/usr/bin/env perl -T

use Test::More skip_all => 'needs update to current code';;
use Test::Deep;
use lib 'lib';

plan qw/no_plan/;

{

    BEGIN { use_ok('Net::DNS::Abstract'); }
    my $dns = Net::DNS::Abstract->new();
    ok($dns);

    my $a = { domain => 'example.com', interface => 'cached' };
    my $b = $dns->axfr($a);
    ok($b);
    cmp_deeply(
        $b, {
            domain => 'example.com',
            interface => 'cached',
        },
        "check hash structure for Cached"
    );
    print Dumper $b;
    $a = { domain => 'example.com', interface => 'hexonet' };
    $b = $dns->axfr($a);
    ok($b);
    cmp_deeply(
        $b, {
            domain => 'example.com',
            interface => 'hexonet',
        },
        "check hash structure for Hexonet"
    );
    print Dumper $b;
    $a = { domain => 'example.com', interface => 'cached' };
    $b = $dns->axfr($a);
    ok($b);
    cmp_deeply(
        $b, {
            domain => 'example.com',
            interface => 'cached',
        },
        "check hash structure for Cached"
    );
    print Dumper $b;

}

done_testing();
