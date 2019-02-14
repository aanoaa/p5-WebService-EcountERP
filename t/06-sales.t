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

    my $res;
    $res = $erp->add('sales', @sales);
    ok($res->{success}, 'sales added');

    $res = $erp->add('sales', @sales);
    is($res->{success}, undef, 'duplicated');
}

done_testing();
