#!/usr/bin/env perl -T

use Test::More skip_all => 'needs update to current code';
use Test::Deep;
use lib 'lib';

plan qw/no_plan/;

{

    BEGIN { use_ok('Net::DNS::Abstract'); }

    my $nda = Net::DNS::Abstract->new(
        domain    => 'iwantmyname.com',
        interface => 'cached',
    );
    ok($nda);

    my $b = $nda->axfr();
    ok($b);
    cmp_deeply(
        $b, {
            domain    => 'iwantmyname.com',
            interface => 'cached',
        },
        "check hash structure for Cached"
    );
    print Dumper $b;
    $nda = Net::DNS::Abstract->new(
        domain    => 'iwantmyname.com',
        interface => 'hexonet',
    );
    $b = $nda->axfr();
    ok($b);
    cmp_deeply(
        $b, {
            domain    => 'iwantmyname.com',
            interface => 'hexonet',
        },
        "check hash structure for Hexonet"
    );
    print Dumper $b;

}

done_testing();
