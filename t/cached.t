#!/usr/bin/perl

use Test::More;
use Test::Deep;
use lib 'lib';

BEGIN { use_ok('Net::DNS::Abstract'); }

subtest 'Author Tests', sub {
    plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.'
        if (not $ENV{TEST_AUTHOR});
    my $dns = Net::DNS::Abstract->new();
    ok($dns);

    my $a = { domain => 'lnz.me', interface => 'Cached' };
    my $b = $dns->axfr($a);
    ok($b);
    cmp_deeply(
        $b, {
            domain    => 'lnz.me',
            interface => 'Cached',
        },
        "check hash structure for Cached"
    );
    print Dumper $b;
    my $c = $dns->update($b, 'Cached');
    ok($c);
    cmp_deeply(
        $c, {
            domain    => 'lnz.me',
            interface => 'Cached',
        },
        "check hash structure for Cached"
    );
    print Dumper $c;
};

done_testing();
