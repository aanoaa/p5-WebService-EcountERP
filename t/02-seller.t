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

    my @sellers = (
        {
            BUSINESS_NO => '1234567890',
            CUST_NAME => 'create customer api test by hshong'
        }
    );

    my $added;
    $added = $erp->add('sellers', @sellers);
    is($added, scalar @sellers, 'seller added');

    $added = $erp->add('sellers', @sellers);
    is($added, 0, 'duplicated');

    @sellers = (
        {
            BUSINESS_NO     => '1234567890',
            CUST_NAME       => 'test',
            G_GUBUN         => '50',
            CUST_LIMIT_TERM => 400,
        },
    );

    $added = $erp->add('sellers', @sellers);
    is($added, undef, 'invalid params');
}

done_testing();
