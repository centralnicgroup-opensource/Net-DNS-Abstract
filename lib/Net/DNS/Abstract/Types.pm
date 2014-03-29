package Net::DNS::Abstract::Types;

use Net::DNS::ZoneFile::Fast;

use Mouse::Util::TypeConstraints;
use MouseX::Types -declare => [qw(Zone)];
use MouseX::Types::Mouse;

use Data::Dump qw/dump/;

type 'Zone',
    as class_type('Net::DNS::Packet'),
    message { "$_ is not a Net::DNS::Packet" };

subtype Zone,     as 'Zone';

for my $type ( 'Zone', Zone ) {
    coerce($type, 
        from 'Str', via { 
            use Net::DNS::Packet;
            my $zone = Net::DNS::ZoneFile::Fast::parse($_);
            my $domain;
            foreach my $rr (@{$zone}){
                next unless $rr->isa('Net::DNS::RR::SOA');
                $domain = $rr->name;
                last;
            }
            my $nd = Net::DNS::Packet->new($domain);
            $nd->push(update => @$zone);
            return $nd;
        },
#        from 'ClassName', via { print STDERR dump($_); Net::DNS::Packet->new('lnz.me') },
#        from 'ScalarRef', via { print STDERR dump($_); Net::DNS::Packet->new('lnz.me') },
#        from 'ArrayRef', via { print STDERR dump($_); Net::DNS::Packet->new('lnz.me') },
#        from 'HashRef', via { print STDERR dump($_); Net::DNS::Packet->new('lnz.me') },
#        from 'CodeRef', via { print STDERR dump($_); Net::DNS::Packet->new('lnz.me') },
#        from 'Object', via { print STDERR dump($_); Net::DNS::Packet->new('lnz.me') },
    );
}

1;
