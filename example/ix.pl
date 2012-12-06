#!/bin/perl -Ilib
#

use 5.010;
use lib '/Users/lenz/work/iwmn/hase/perl/lib/';
use Net::DNS::Abstract;
use Net::DNS::Abstract::Plugins::InternetX::Direct;
use Data::Dumper;

my $ix_ref = Net::DNS::Abstract::Plugins::InternetX::Direct->new();
$ix_ref->ix_login({ user => '12IDN', pass => 'ce549B8e5i', context => 4 });

my $dns = Net::DNS::Abstract->new(debug => 1);
my $query = {
    domain    => 'lnz.me',
    interface => 'InternetX',
    ns        => [ 'ns1.iwantmyname.net', 'ns2.iwantmynme.net' ],
    ix_ref    => $ix_ref,
};

my $res = $dns->axfr($query);
#print Dumper($res);

say "\n###### Got Answer for lnz.me ########";
say $dns->to_string($res);
