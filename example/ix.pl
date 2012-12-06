#!/bin/perl -Ilib
#

use 5.010;
use lib '.';
use Net::DNS::Abstract;
use Net::DNS::Abstract::Plugins::InternetX::Direct;
use Data::Dumper;

my $ix_ref = Net::DNS::Abstract::Plugins::InternetX::Direct->new();
$ix_ref->ix_login({ user => 'user', pass => 'password', context => 4 });

my $dns = Net::DNS::Abstract->new(debug => 1);
my $query = {
    domain    => 'domain.tld',
    interface => 'InternetX',
    ns        => [ 'ns1.iwantmyname.net', 'ns2.iwantmynme.net' ],
    ix_ref    => $ix_ref,
};

my $res = $dns->axfr($query);
#print Dumper($res);

say "\n###### Got Answer for domain.tld ########";
say $dns->to_string($res);
