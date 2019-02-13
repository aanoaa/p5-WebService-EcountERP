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

    my @products = (
        {
            PROD_CD  => 'XXX-001',
            PROD_DES => 'test product',
        },
    );

    my $added;
    $added = $erp->add('products', @products);
    is($added, scalar @products, 'seller added');

    $added = $erp->add('products', @products);
    is($added, 0, 'duplicated');

    @products = (
        {
            VAT_YN => 'M',
        },
        {
            PROD_CD => '',
        },
        {
            CSORD_C0003 => '1010'
        }
    );

    $added = $erp->add('products', @products);
    is($added, undef, 'invalid params');
}

done_testing();
