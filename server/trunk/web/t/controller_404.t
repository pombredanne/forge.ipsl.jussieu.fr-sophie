use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::404' }

ok( request('/404')->is_success, 'Request should succeed' );
done_testing();
