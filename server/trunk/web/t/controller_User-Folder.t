use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::User::Folder' }

ok( request('/user/folder')->is_success, 'Request should succeed' );
done_testing();
