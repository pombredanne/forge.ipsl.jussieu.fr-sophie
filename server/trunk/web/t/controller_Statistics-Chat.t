use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Statistics::Chat' }

ok( request('/statistics/chat')->is_success, 'Request should succeed' );
ok( request('/statistics/chat/command_graph')->is_success, 'Request should succeed' );
done_testing();
