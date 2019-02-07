package WebService::EcountERP;

use utf8;
use strict;
use warnings;

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

=over $lan_type

language type

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

    print "$res->{status}\n";
    print "$res->{content}\n";

    unless ($res->{success}) {
        warn "$res->{status}: $res->{reason}\n";
        return;
    }

    my $self = {
        login => $login,
        http  => $http,
    };

    return bless $self, $class;
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
