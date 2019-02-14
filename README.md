# WebService-EcountERP #

perl interface to ecounterp.com

``` perl
my $erp = WebService::EcountERP->new(
    com_code     => '1234567',
    user_id      => 'username',
    api_cert_key => 'xxxxxxx',
    zone         => 'C'
);

## reuse session_id
my $erp = WebService::EcountERP->new(
    session => 'session-file',
    zone    => 'C'
);

die "login failed" unless $erp;

my $result = $erp->add('products', @products);
die "wrong products parameter spec" unless $result;

unless ($result->{success}) {
    print $result->errors_to_string;
}
```
