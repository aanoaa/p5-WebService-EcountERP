package WebService::EcountERP;

use utf8;
use strict;
use warnings;

use experimental 'switch';

use HTTP::Tiny;
use JSON::PP;

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
    return unless $args{com_code};
    return unless $args{user_id};
    return unless $args{api_cert_key};
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
        warn "$error\n";
        warn "  $detail\n" if $detail;
        return;
    }

    my $session_id;
    unless ($session_id = $result->{Data}{Datas}{SESSION_ID}) {
        warn "Session ID not found: $out\n";
        return;
    }

    my $self = {
        login      => $login,
        http       => $http,
        session_id => $session_id,
    };

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

    given($type) {
        when (/products/) {
            return $self->_add_products(@params);
        }
        default {
            warn "type not found: $type";
            return;
        }
    }
}

=head2 _add_products($code, $name, \@products)

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
    my ($self, @products) = @_;

    return unless $self->is_auth;

    my @REQUIRED = qw/PROD_CD PROD_DES/;
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

    my $params = $self->_build_bulk_data('ProductList', \@REQUIRED, \@PARAMS, @products);
    unless ($params) {
        warn "Failed to build bulk data";
        return;
    }

    my $zone = $self->{login}{zone};
    my $session_id = $self->{session_id};
    my $url = sprintf("https://oapi%s.ecounterp.com/OAPI/V2/InventoryBasic/SaveBasicProduct?SESSION_ID=%s", $zone, $session_id);
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

    my $expected = scalar @{ $params->{ProductList} };
    return $self->parse_response($res, $expected);
}

sub _build_bulk_data {
    my ($self, $key, $required, $params, @items) = @_;
    return unless $key;
    return unless $required;
    return unless $params;
    return unless @items;

    my %available;
    map { $available{$_}++ } @$params;

    my $line = 0;
    my @data;
    for my $item (@items) {
        for my $field (@$required) {
            unless ($item->{$field}) {
                warn "$field is required";
                next;
            }
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

    return { $key => \@data };
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
