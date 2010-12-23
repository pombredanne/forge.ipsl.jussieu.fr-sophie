use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Feed::My' }

ok( request('/feed/my')->is_success, 'Request should succeed' );
done_testing();
