#!/usr/bin/perl

use Test::More;
use Test::Deep;
use lib 'lib';

plan qw/no_plan/;

{

    BEGIN { use_ok('Net::DNS::Abstract'); }
    my $dns = Net::DNS::Abstract->new();
    ok($dns);

    my $a = { domain => 'example.com', interface => 'InternetX' };
    my $b = $dns->axfr($a);
    ok($b);
    cmp_deeply(
        $b, {
            domain => 'example.com'
        },
        "check hash structure"
    );
    print Dumper $b;

}

