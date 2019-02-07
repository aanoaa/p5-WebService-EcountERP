use utf8;
use strict;
use warnings;
use open ':std', ':encoding(utf8)';
use Test::More;

use WebService::EcountERP;

my $com_code     = $ENV{WEBSERVICE_ECOUNTERP_COM_CODE};
my $user_id      = $ENV{WEBSERVICE_ECOUNTERP_USER_ID};
my $api_cert_key = $ENV{WEBSERVICE_ECOUNTERP_API_CERT_KEY};
my $zone         = $ENV{WEBSERVICE_ECOUNTERP_ZONE};

my $erp = WebService::EcountERP->new(
    com_code     => $com_code,
    user_id      => $user_id,
    api_cert_key => $api_cert_key,
    zone         => $zone
);

SKIP: {
    skip 'com_code, user_id, api_cert_key, zone are required' unless $erp;
    ok(1);
}

done_testing();
