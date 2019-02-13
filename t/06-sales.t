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

    my @sales = (
        {
            UPLOAD_SER_NO  => '1',                                 # 순번
            WH_CD          => 'XX999',                             # 출하창고
            PROD_CD        => 'XXX-001',                           # 품목코드
            PROD_DES       => 'create product api test by hshong', # 품목명
            QTY            => 1,                                   # 수량
            PRICE          => 100,                                 # 단가
            USER_PRICE_VAT => 100,                                 # 단가 VAT 포함
            SUPPLY_AMT     => 100,                                 # 공급가액
            SUPPLY_AMT_F   => 0,                                   # 공급가액(외화)
            VAT_AMT        => 0,                                   # 부가세
            REMARKS        => '',                                  # 적요
            CUST_AMT       => '',                                  # 부대비용
            MAKE_FLAG      => 'N',                                 # 생산전표생성
        }
    );

    my $added;
    $added = $erp->add('sales', @sales);
    is($added, scalar @sales, 'seller added');

    $added = $erp->add('sales', @sales);
    is($added, 0, 'duplicated');

    @sales = (
        {
            UPLOAD_SER_NO => '',
        },
        {
            REL_DATE => 1231123123123,
        },
        {
            MAKE_FLAG => 'O'
        }
    );

    $added = $erp->add('sales', @sales);
    is($added, undef, 'invalid params');
}

done_testing();
