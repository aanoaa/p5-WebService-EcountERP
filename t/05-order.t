use utf8;
use strict;
use warnings;
use open ':std', ':encoding(utf8)';
use Test::More;

use WebService::EcountERP;

my $zone = $ENV{WEBSERVICE_ECOUNTERP_ZONE};
open my $fh, '<', '.tmp-session' or die "Can't open .tmp-session: $!";
my $session_id = <$fh>;

SKIP: {
    skip 'session_id and zone are required' unless $session_id or $zone;
    my $erp = WebService::EcountERP->new(
        session_id => $session_id,
        zone       => $zone
    );

    ok($erp, 'new - session_id');

    my @orders = (
        {
            UPLOAD_SER_NO => 1,
            WH_CD         => 'XX999',
            PROD_CD       => 'XXX-001',
            QTY           => 1,
        }
    );

    my $added;
    $added = $erp->add('orders', @orders);
    is($added, scalar @orders, 'seller added');

    $added = $erp->add('orders', @orders);
    is($added, 0, 'duplicated');

    @orders = (
        {
            UPLOAD_SER_NO => '',
        },
        {
            EXCHANGE_TYPE => '1234abcdfsf',
        },
        {
            ITEM_TIME_DATE => 'afsdfjkdsljflkasjdfkl'
        }
    );

    $added = $erp->add('orders', @orders);
    is($added, undef, 'invalid params');
}

done_testing();
