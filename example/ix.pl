#!/bin/perl -Ilib
#

use 5.010;
use lib '/Users/lenz/work/iwmn/hase/perl/lib/';
use Net::DNS::Abstract;
use Net::DNS::Abstract::Plugins::InternetX::Direct;
use Data::Dumper;
use Daemonise;

my $ix_ref = Daemonise->new();
my $dns = Net::DNS::Abstract->new(debug => 1);
my $query = {
    domain    => 'lnz.me',
    interface => 'internetx',
    ns        => [ 'ns1.iwantmyname.net', 'ns2.iwantmynme.net' ],
    internetx_transport => $ix_ref,
};

my $res = $dns->axfr($query);
print Dumper($res);

say "\n###### Got Answer for lnz.me ########";
#say $dns->to_string($res);
