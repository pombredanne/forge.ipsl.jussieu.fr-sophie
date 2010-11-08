use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Explorer' }

ok( request('/explorer')->is_success, 'Request should succeed' );
done_testing();
