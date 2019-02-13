use strict;
use warnings;
use open ':std', ':encoding(utf8)';
use Test::More tests => 1;

ok(unlink '.tmp-session', 'delete tmp session');
