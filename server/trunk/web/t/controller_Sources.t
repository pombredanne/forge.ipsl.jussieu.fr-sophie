use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Sources' }

ok( request('/sources')->is_success, 'Request should succeed' );
ok( request('/sources?search=rpm')->is_success, 'Request should succeed' );
ok( request('/sources/rpm')->is_success, 'Request should succeed' );
done_testing();
