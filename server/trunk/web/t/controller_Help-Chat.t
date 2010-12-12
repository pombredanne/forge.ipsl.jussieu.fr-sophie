use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Help::Chat' }

ok( request('/help/chat')->is_success, 'Request should succeed' );
done_testing();
