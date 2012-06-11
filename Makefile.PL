use inc::Module::Install;

name     'Net-DNS-Abstract';
all_from 'lib/Net/DNS/Abstract.pm';
author   q{Lenz Gschwendtner <norbu09@cpan.org>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

