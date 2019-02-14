use utf8;
use strict;
use warnings;
use open ':std', ':encoding(utf8)';
use Test::More;

use WebService::EcountERP;

my $zone = $ENV{WEBSERVICE_ECOUNTERP_ZONE};

SKIP: {
    skip 'session_id and zone are required' unless -e '.tmp-session' or $zone;
    my $erp = WebService::EcountERP->new(
        session => '.tmp-session',
        zone    => $zone
    );

    ok($erp, 'new - session file');

    my @sellers = (
        {
            BUSINESS_NO => '1234567890',
            CUST_NAME   => 'test seller'
        }
    );

    my $res;
    $res = $erp->add('sellers', @sellers);
    ok($res, 'authenticated');
    ok($res->{success}, 'seller added');

    $res = $erp->add('sellers', @sellers);
    is($res->{success}, undef, 'duplicated');
    ok($res->errors_to_string, 'filled error');
}

done_testing();
