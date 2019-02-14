package WebService::EcountERP::Result;

use utf8;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = {
        errors      => [],
        success     => undef,
        success_cnt => 0,
        failed_cnt  => 0,
        response    => undef,
    };

    map {
        $self->{$_} = $args{$_} if exists $args{$_};
    } keys %$self;

    return bless $self, $class;
}

sub errors_to_string {
    my $self = shift;
    return join "\n", @{ $self->{errors} };
}

1;
