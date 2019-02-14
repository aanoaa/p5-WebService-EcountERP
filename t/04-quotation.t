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

    my @quotations = (
        {
            UPLOAD_SER_NO => 1,
            PROD_CD       => 'XXX-001',
            QTY           => 1
        }
    );

    my $res;
    $res = $erp->add('quotations', @quotations);
    ok($res->{success}, 'quotations added');

    $res = $erp->add('quotations', @quotations);
    is($res->{success}, undef, 'duplicated');
}

done_testing();
