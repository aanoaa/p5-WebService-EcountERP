package WebService::EcountERP;

use utf8;
use strict;
use warnings;

use experimental 'switch';

use HTTP::Tiny;
use JSON::PP;
use Validation::Class::Simple;

=encoding utf8

=head1 NAME

WebService::EcountERP - Perl interface to EcountERP API

=head1 SYNOPSIS

    my $erp = WebService::EcountERP->new(
      com_code     => '1234567',
      user_id      => 'username',
      api_cert_key => 'xxxxxxx',
      zone         => 'C'
    );

    die "Failed to signed in" unless $erp->login;

=cut

our %LAN_TYPE = (
    'ko-KR' => '한국어 (Default)',
    'en-US' => 'English',
    'zh-CN' => '简体中文',
    'zh-TW' => '繁体中文',
    'ja-JP' => '日本語',
    'vi-VN' => 'Việt Nam',
    'es'    => 'Español',
    'id-ID' => 'Indonesian',
);

our $URL_FORMAT = 'https://oapi%s.ecounterp.com/OAPI/V2/%s/%s?SESSION_ID=%s';

=head1 METHODS

=head2 new( com_code => $com_code, user_id => $user_id, api_cert_key => $api_cert_key, zone => $zone, lan_type => $lan_type )

L<로그인 API|https://login.ecounterp.com/ECERP/OAPI/OAPIView?lan_type=ko-KR>

=head3 C<$lan_type>

language type

=over

=item *

ko-KR: 한국어 (Default)

=item *

en-US: English

=item *

zh-CN: 简体中文

=item *

zh-TW: 繁体中文

=item *

ja-JP: 日本語

=item *

vi-VN: Việt Nam

=item *

es: Español
n
=item *

id-ID: Indonesian

=back

=cut

sub new {
    my ($class, %args) = @_;
    return unless $args{session_id} or ($args{com_code} and $args{user_id} and $args{api_cert_key});
    return unless $args{zone};

    my $login = {};
    map { $login->{$_} = $args{$_} } qw/com_code user_id api_cert_key zone/;
    $login->{lan_type} = $LAN_TYPE{$args{lan_type} || ''} || 'ko-KR';

    my $http = HTTP::Tiny->new(
        default_headers => {
            agent  => 'WebService::EcountERP - Perl interface to EcountERP API',
            Accept => 'application/json'
        }
    );

    my $self = {
        login => $login,
        http  => $http,
    };

    if ($args{session_id}) {
        $self->{session_id} = $args{session_id};
        return bless $self, $class;
    }

    my $url = sprintf('https://oapi%s.ecounterp.com/OAPI/V2/OAPILogin', lc $login->{zone});

    my $json = encode_json $login;
    my $res = $http->post($url, {
        headers => {
            'Content-Type' => 'application/json',
        },
        content => $json,
    });

    unless ($res->{success}) {
        warn "$res->{status}: $res->{reason}\n";
        return;
    }

    my $out = $res->{content};
    my $result = decode_json $out;

    my $status = $result->{Status};
    if ($status !~ m/200/ ) {
        my $error  = $result->{Error}{Message} || "Unknown error occurred: $out";
        my $detail = $result->{Error}{MessageDetail};
        warn "$status: $error\n";
        warn "  $detail\n" if $detail;
        return;
    }

    my $session_id;
    unless ($session_id = $result->{Data}{Datas}{SESSION_ID}) {
        warn "Session ID not found: $out\n";
        return;
    }

    $self->{session_id} = $session_id;
    return bless $self, $class;
}

=head2 is_auth

=cut

sub is_auth {
    my $self = shift;

    my $zone = $self->{login}{zone};
    my $session_id = $self->{session_id};

    return unless $zone;
    return unless $session_id;
    return 1;
}

=head2 parse_response($res, $expected_cnt)

=over

=item *

C<$res>

L<HTTP::Tiny> response object

=item *

C<$expected_cnt>

Whether the criteria for success or not

=back

=cut

sub parse_response {
    my ($self, $res, $expected) = @_;

    my $out = $res->{content};
    my $result = decode_json $out;

    my $status = $result->{Status};
    if ($status !~ m/200/ ) {
        my $error  = $result->{Error}{Message} || "Unknown error occurred: $out";
        my $detail = $result->{Error}{MessageDetail};
        warn "$status: $error\n";
        warn "  $detail\n" if $detail;
        return 0;
    }

    my $success_cnt = $result->{Data}{SuccessCnt};
    my $failed_cnt  = $result->{Data}{FailCnt};
    if ($success_cnt != $expected) {
        for my $detail (@{ $result->{Data}{ResultDetails} }) {
            next if my $is_success = $detail->{IsSuccess};

            my $n       = $detail->{Line};
            my $error   = $detail->{TotalError};
            warn "Line($n): $error";

            for my $err (@{ $detail->{Errors} }) {
                my $column  = $err->{ColCd};
                my $message = $err->{Message};
                warn "  $column: $message";
            }
        }
    }

    return $success_cnt;
}

=head2 add($type => \%params)

C<$type> 에 따라 C<\%params> 가 바뀝니다.

=head3 C<$type>

=over

=item *

product: 품목등록

=back

=cut

sub add {
    my ($self, $type, @params) = @_;
    return unless $type;
    return unless @params;
    return unless $self->is_auth;

    my $zone = $self->{login}{zone};
    my $session_id = $self->{session_id};

    given($type) {
        when (/sellers/) {
            my $url = sprintf($URL_FORMAT, $zone, 'AccountBasic', 'SaveBasicCust', $session_id);
            return $self->_add_sellers($url, 'CustList', @params);
        }
        when (/products/) {
            my $url = sprintf($URL_FORMAT, $zone, 'InventoryBasic', 'SaveBasicProduct', $session_id);
            return $self->_add_products($url, 'ProductList', @params);
        }
        when (/quotations/) {
            my $url = sprintf($URL_FORMAT, $zone, 'Quotation', 'SaveQuotation', $session_id);
            return $self->_add_quotations($url, 'QuotationList', @params);
        }
        when (/orders/) {
            my $url = sprintf($URL_FORMAT, $zone, 'SaleOrder', 'SaveSaleOrder', $session_id);
            return $self->_add_orders($url, 'SaleOrderList', @params);
        }
        when (/sales/) {
            my $url = sprintf($URL_FORMAT, $zone, 'Sale', 'SaveSale', $session_id);
            return $self->_add_sales($url, 'SaleList', @params);
        }
        default {
            warn "type not found: $type";
            return;
        }
    }
}

=head2 _add_sellers($url, $key, @sellers)

L<https://login.ecounterp.com/ECERP/OAPI/OAPIView?lan_type=ko-KR#|거래처등록>

=head3 C<@sellers>

keys C<BUSINESS_NO> and C<CUST_NAME> are required.
others are optional.

    [
      {
        BUSINESS_NO => '1234567890',    # employer ID number
        CUST_NAME   => 'foo',           # seller name
      }
    ]

=cut

sub _add_sellers {
    my ($self, $url, $key, @sellers) = @_;
    return unless $self->is_auth;

    my @PARAMS = qw/BUSINESS_NO CUST_NAME BOSS_NAME UPTAE JONGMOK TEL EMAIL POST_NO ADDR
                    G_GUBUN G_BUSINESS_TYPE G_BUSINESS_CD TAX_REG_ID FAX HP_NO DM_POST
                    DM_ADDR REMARKS_WIN GUBUN FOREIGN_FLAG EXCHANGE_CODE CUST_GROUP1
                    CUST_GROUP2 URL_PATH REMARKS OUTORDER_YN IO_CODE_SL_BASE_YN IO_CODE_SL
                    IO_CODE_BY_BASE_YN IO_CODE_BY EMP_CD MANAGE_BOND_NO MANAGE_DEBIT_NO
                    CUST_LIMIT MAIN_CD O_RATE I_RATE PRICE_GROUP PRICE_GROUP2
                    CUST_LIMIT_TERM CONT1 CONT2 CONT3 CONT4 CONT5 CONT6 NO_CUST_USER1
                    NO_CUST_USER2 NO_CUST_USER3 CANCEL/;

    my $regexYN = qr/^[YN]$/;
    my $regexMBYN = qr/^[MBYN]$/;
    my $rules = Validation::Class::Simple->new(
        fields => {
            BUSINESS_NO        => { required => 1 },
            CUST_NAME          => { required => 1 },
            G_GUBUN            => { pattern => qr/^0[123]$/ },
            G_BUSINESS_TYPE    => { pattern => qr/^[123]$/ },
            GUBUN              => { pattern => qr/^1[13]$/ }, # 일반거래처 : 11, 관세사거래처 : 13
            FOREIGN_FLAG       => { pattern => $regexYN },
            OUTORDER_YN        => { pattern => $regexYN },
            IO_CODE_SL_BASE_YN => { pattern => $regexYN },
            IO_CODE_BY_BASE_YN => { pattern => $regexYN },
            MANAGE_BOND_NO     => { pattern => $regexMBYN },
            MANAGE_DEBIT_NO    => { pattern => $regexMBYN },
            CUST_LIMIT_TERM    => { between => '1-365' },
            CANCEL             => { pattern => $regexYN },
        }
    );

    my $params = $self->_build_bulk_data($key, $rules, \@PARAMS, @sellers);
    unless ($params) {
        warn "Failed to build bulk data";
        return;
    }

    my $http = $self->{http};
    my $json = encode_json $params;
    my $res = $http->post($url, {
        headers => {
            'Content-Type' => 'application/json',
        },
        content => $json,
    });

    unless ($res->{success}) {
        warn "$res->{status}: $res->{reason}\n";
        return;
    }

    my $expected = scalar @{ $params->{$key} };
    return $self->parse_response($res, $expected);
}

=head2 _add_products($url, $key, @products)

L<https://login.ecounterp.com/ECERP/OAPI/OAPIView?lan_type=ko-KR#|품목등록>

=head3 C<@products>

keys C<PROD_CD> and C<PROD_DES> are required.
others are optional.

    [
      {
        PROD_CD  => '123',    # product code
        PROD_DES => 'foo',    # product name or description
      }
    ]

=cut

sub _add_products {
    my ($self, $url, $key, @products) = @_;
    return unless $self->is_auth;

    my @PARAMS = qw/PROD_CD PROD_DES SIZE_FLAG SIZE_DES UNIT PROD_TYPE SET_FLAG BAL_FLAG
                    WH_CD IN_PRICE IN_PRICE_VAT OUT_PRICE OUT_PRICE_VAT REMARKS_WIN
                    CLASS_CD CLASS_CD2 CLASS_CD3 BAR_CODE VAT_YN TAX VAT_RATE_BY_BASE_YN
                    VAT_RATE_BY CS_FLAG REMARKS INSPECT_TYPE_CD INSPECT_STATUS
                    SAMPLE_PERCENT MAIN_PROD_CD MAIN_PROD_CONVERT_QTY INPUT_QTY EXCH_RATE
                    DENO_RATE SAFE_A0001 SAFE_A0002 SAFE_A0003 SAFE_A0004 SAFE_A0005
                    SAFE_A0006 SAFE_A0007 CSORD_C0001 CSORD_TEXT CSORD_C0003 IN_TERM
                    MIN_QTY CUST OUT_PRICE1 OUT_PRICE1_VAT_YN OUT_PRICE2 OUT_PRICE2_VAT_YN
                    OUT_PRICE3 OUT_PRICE3_VAT_YN OUT_PRICE4 OUT_PRICE4_VAT_YN OUT_PRICE5
                    OUT_PRICE5_VAT_YN OUT_PRICE6 OUT_PRICE6_VAT_YN OUT_PRICE7
                    OUT_PRICE7_VAT_YN OUT_PRICE8 OUT_PRICE8_VAT_YN OUT_PRICE9
                    OUT_PRICE9_VAT_YN OUT_PRICE10 OUT_PRICE10_VAT_YN OUTSIDE_PRICE
                    OUTSIDE_PRICE_VAT LABOR_WEIGHT EXPENSES_WEIGHT MATERIAL_COST
                    EXPENSE_COST LABOR_COST OUT_COST CONT1 CONT2 CONT3 CONT4 CONT5 CONT6
                    NO_USER1 NO_USER2 NO_USER3 NO_USER4 NO_USER5 NO_USER6 NO_USER7
                    NO_USER8 NO_USER9 NO_USER10 ITEM_TYPE SERIAL_TYPE PROD_SELL_TYPE
                    PROD_WHMOVE_TYPE QC_BUY_TYPE QC_YN/;

    my $regexYN   = qr/^[YN]$/;
    my $regexMBYN = qr/^[MBYN]$/;
    my $regexBYN  = qr/^[BYN]$/;
    my $regex01   = qr/^[10]$/;
    my $regex012  = qr/^[012]$/;
    my $rules = Validation::Class::Simple->new(
        fields => {
            PROD_CD            => { required => 1 },
            PROD_DES           => { required => 1 },
            SIZE_FLAG          => { pattern => qr/^[1234]$/ },   # 규격구분설정(1:규격명, 2:규격그룹, 3:규격계산, 4:규격계산그룹)
            PROD_TYPE          => { pattern => qr/^[041237]$/ }, # 품목구분 : 원재료0, 부재료4, 제품1, 반제품2, 상품3, 무형상품7
            SET_FLAG           => { pattern => $regex01 },
            BAL_FLAG           => { pattern => $regex01 },
            IN_PRICE_VAT       => { pattern => $regex01 },
            OUT_PRICE_VAT      => { pattern => $regex01 },
            VAT_YN             => { pattern => $regexYN },
            CS_FLAG            => { pattern => $regex01 },
            INSPECT_STATUS     => { pattern => qr/^[LS]$/ },     # 품질검사방법설정(L:전수, S:샘플링)
            SAFE_A0001         => { pattern => $regex012 },
            SAFE_A0002         => { pattern => $regex012 },
            SAFE_A0003         => { pattern => $regex012 },
            SAFE_A0004         => { pattern => $regex012 },
            SAFE_A0005         => { pattern => $regex012 },
            SAFE_A0006         => { pattern => $regex012 },
            SAFE_A0007         => { pattern => $regex012 },
            CSORD_C0001        => { pattern => $regexBYN },
            CSORD_C0003        => { pattern => $regexYN },
            OUT_PRICE1_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE2_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE3_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE4_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE5_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE6_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE7_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE8_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE9_VAT_YN  => { pattern => $regexYN },
            OUT_PRICE10_VAT_YN => { pattern => $regexYN },
            ITEM_TYPE          => { pattern => $regexMBYN },
            SERIAL_TYPE        => { pattern => $regexMBYN },
            PROD_SELL_TYPE     => { pattern => $regexBYN },
            PROD_WHMOVE_TYPE   => { pattern => $regexBYN },
            QC_BUY_TYPE        => { pattern => $regexBYN },
            QC_YN              => { pattern => $regexYN },
        }
    );

    my $params = $self->_build_bulk_data($key, $rules, \@PARAMS, @products);
    unless ($params) {
        warn "Failed to build bulk data";
        return;
    }

    my $http = $self->{http};
    my $json = encode_json $params;
    my $res = $http->post($url, {
        headers => {
            'Content-Type' => 'application/json',
        },
        content => $json,
    });

    unless ($res->{success}) {
        warn "$res->{status}: $res->{reason}\n";
        return;
    }

    my $expected = scalar @{ $params->{$key} };
    return $self->parse_response($res, $expected);
}

=head2 _add_quotations($url, $key, @quotations)

L<https://login.ecounterp.com/ECERP/OAPI/OAPIView?lan_type=ko-KR#|견적서입력>

=head3 C<@quotations>

    {
      UPLOAD_SER_NO => '1',
      PROD_CD       => 'xxx',
      QTY           => '10',
    }

=over

=item *

C<UPLOAD_SER_NO>

required

If you want to bundle the same document, enter the same order number.
동일한 전표로 묶고자 하는 경우 동일 순번을 입력

=item *

C<PROD_CD>

required

ERP product code

=item *

C<QTY>

required

product quantity

=back

=cut

sub _add_quotations {
    my ($self, $url, $key, @quotations) = @_;
    return unless $self->is_auth;

    my @PARAMS = qw/UPLOAD_SER_NO IO_DATE CUST CUST_DES EMP_CD WH_CD IO_TYPE EXCHANGE_TYPE
                    EXCHANGE_RATE PJT_CD DOC_NO REF_DES COLL_TERM AGREE_TERM U_MEMO1
                    U_MEMO2 U_MEMO3 U_MEMO4 U_MEMO5 U_TXT1 PROD_CD PROD_DES SIZE_DES UQTY
                    QTY PRICE USER_PRICE_VAT SUPPLY_AMT SUPPLY_AMT_F VAT_AMT REMARKS
                    ITEM_CD P_AMT1 P_AMT2 P_REMARKS1 P_REMARKS2 P_REMARKS3/;

    my $rules = Validation::Class::Simple->new(
        fields => {
            UPLOAD_SER_NO => { required => 1 },
            PROD_CD       => { required => 1 },
            QTY           => { required => 1 },
            IO_TYPE       => { max_length => 2 },
            EXCHANGE_TYPE => { max_length => 5 },
        }
    );

    my $params = $self->_build_bulk_data($key, $rules, \@PARAMS, @quotations);
    unless ($params) {
        warn "Failed to build bulk data";
        return;
    }

    my $http = $self->{http};
    my $json = encode_json $params;
    my $res = $http->post($url, {
        headers => {
            'Content-Type' => 'application/json',
        },
        content => $json,
    });

    unless ($res->{success}) {
        warn "$res->{status}: $res->{reason}\n";
        return;
    }

    my $expected = scalar @{ $params->{$key} };
    return $self->parse_response($res, $expected);
}

=head2 _add_orders($url, $key, @orders)

L<https://login.ecounterp.com/ECERP/OAPI/OAPIView?lan_type=ko-KR#|주문서입력>

=head3 C<@quotations>

    {
      UPLOAD_SER_NO => '1',
      WH_CD         => '중앙창고',
      PROD_CD       => 'xxx',
      QTY           => '10',
    }

=over

=item *

C<UPLOAD_SER_NO>

required

If you want to bundle the same document, enter the same order number.
동일한 전표로 묶고자 하는 경우 동일 순번을 입력

=item *

C<WH_CD>

ERP warehouse code

=item *

C<PROD_CD>

required

ERP product code

=item *

C<QTY>

required

product quantity

=back

=cut

sub _add_orders {
    my ($self, $url, $key, @orders) = @_;
    return unless $self->is_auth;

    my @PARAMS = qw/UPLOAD_SER_NO IO_DATE CUST CUST_DES EMP_CD WH_CD IO_TYPE EXCHANGE_TYPE
                    EXCHANGE_RATE PJT_CD DOC_NO REF_DES COLL_TERM AGREE_TERM TIME_DATE
                    REMARKS_WIN U_MEMO1 U_MEMO2 U_MEMO3 U_MEMO4 U_MEMO5 U_TXT1 PROD_CD
                    PROD_DES SIZE_DES UQTY QTY PRICE USER_PRICE_VAT SUPPLY_AMT
                    SUPPLY_AMT_F VAT_AMT ITEM_TIME_DATE REMARKS ITEM_CD P_AMT1 P_AMT2
                    P_REMARKS1 P_REMARKS2 P_REMARKS3 REL_DATE REL_NO/;

    my $rules = Validation::Class::Simple->new(
        fields => {
            UPLOAD_SER_NO  => { required => 1 },
            WH_CD          => { required => 1, max_length => 5 },
            PROD_CD        => { required => 1 },
            QTY            => { required => 1 },
            IO_TYPE        => { max_length => 2 },
            EXCHANGE_TYPE  => { max_length => 5 },
            TIME_DATE      => { max_length => 8 },
            U_MEMO1        => { max_length => 6 },
            ITEM_TIME_DATE => { max_length => 8 },
            REL_DATE       => { max_length => 8 },
        }
    );

    my $params = $self->_build_bulk_data($key, $rules, \@PARAMS, @orders);
    unless ($params) {
        warn "Failed to build bulk data";
        return;
    }

    my $http = $self->{http};
    my $json = encode_json $params;
    my $res = $http->post($url, {
        headers => {
            'Content-Type' => 'application/json',
        },
        content => $json,
    });

    unless ($res->{success}) {
        warn "$res->{status}: $res->{reason}\n";
        return;
    }

    my $expected = scalar @{ $params->{$key} };
    return $self->parse_response($res, $expected);
}

=head2 _add_sales($url, $key, @sales)

L<https://login.ecounterp.com/ECERP/OAPI/OAPIView?lan_type=ko-KR#|판매입력>

=head3 C<@quotations>

    {
      UPLOAD_SER_NO => '1',
      WH_CD         => '중앙창고',
      PROD_CD       => 'xxx',
      QTY           => '10',
    }

=over

=item *

C<UPLOAD_SER_NO>

required

If you want to bundle the same document, enter the same order number.
동일한 전표로 묶고자 하는 경우 동일 순번을 입력

=item *

C<WH_CD>

ERP warehouse code

=item *

C<PROD_CD>

required

ERP product code

=item *

C<QTY>

required

product quantity

=back

=cut

sub _add_sales {
    my ($self, $url, $key, @sales) = @_;
    return unless $self->is_auth;

    my @REQUIRED = qw/UPLOAD_SER_NO WH_CD PROD_CD QTY/;
    my @PARAMS = qw/UPLOAD_SER_NO IO_DATE CUST CUST_DES EMP_CD WH_CD IO_TYPE EXCHANGE_TYPE
                    EXCHANGE_RATE PJT_CD DOC_NO U_MEMO1 U_MEMO2 U_MEMO3 U_MEMO4 U_MEMO5
                    U_TXT1 PROD_CD PROD_DES SIZE_DES UQTY QTY PRICE USER_PRICE_VAT
                    SUPPLY_AMT SUPPLY_AMT_F VAT_AMT REMARKS ITEM_CD P_AMT1 P_AMT2
                    P_REMARKS1 P_REMARKS2 P_REMARKS3 REL_DATE REL_NO MAKE_FLAG CUST_AMT/;

    my $params = $self->_build_bulk_data($key, \@REQUIRED, \@PARAMS, @sales);
    unless ($params) {
        warn "Failed to build bulk data";
        return;
    }

    my $http = $self->{http};
    my $json = encode_json $params;
    my $res = $http->post($url, {
        headers => {
            'Content-Type' => 'application/json',
        },
        content => $json,
    });

    unless ($res->{success}) {
        warn "$res->{status}: $res->{reason}\n";
        return;
    }

    my $expected = scalar @{ $params->{$key} };
    return $self->parse_response($res, $expected);
}

=head2 _build_bulk_data($key, $rules, \@params, @items)

C<$key> is string.

C<$rules> is L<Validation::Class::Simple> object.

=cut

sub _build_bulk_data {
    my ($self, $key, $rules, $params, @items) = @_;
    return unless $key;
    return unless $params;
    return unless @items;

    my %available;
    map { $available{$_}++ } @$params;

    my $line = 0;
    my @data;
    for my $item (@items) {
        $rules->reset_params($item);
        unless ($rules->validate) {
            warn $rules->errors_to_string;
            next;
        }

        my %param;
        for my $key (keys %$item) {
            my $value = $item->{$key};
            unless ($available{$key}) {
                warn "Invalid parameter: $key($value)";
                next;
            }

            $param{$key} = $value;
        }

        push @data, {
            Line      => $line++,
            BulkDatas => \%param,
        };
    }

    return @data ? { $key => \@data } : undef;
}

# login(로그인)
# customer(거래처 등록)
# product(품목등록)
# Quotation(견적서 입력)
# order(주문서 입력)
# sales or sell(판매입력)
# 작업지시서 입력
# 생산불출입력
# 매출-매입전표 II 자동분개
# 주문API 쇼핑몰관리

1;
