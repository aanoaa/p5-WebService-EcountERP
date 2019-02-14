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

    my $res;
    $res = $erp->add('products', @products);
    ok($res->{success}, 'products added');

    $res = $erp->add('products', @products);
    is($res->{success}, undef, 'duplicated');
}

done_testing();
