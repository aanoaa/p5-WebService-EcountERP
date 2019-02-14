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

    my @orders = (
        {
            UPLOAD_SER_NO => 1,
            WH_CD         => 'XX999',
            PROD_CD       => 'XXX-001',
            QTY           => 1,
        }
    );

    my $res;
    $res = $erp->add('orders', @orders);
    ok($res->{success}, 'orders added');

    $res = $erp->add('orders', @orders);
    is($res->{success}, undef, 'duplicated');
}

done_testing();
