use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Feed::Last' }

ok( request('/feed/last/srpms.rss')->is_success, 'Request should succeed' );
ok( request('/feed/last/Mdv,cooker,i586/srpms.rss')->is_success, 'Request should succeed' );
ok( request('/feed/last/cooker,i586/srpms.rss')->is_success, 'Request should succeed' );
ok( request('/feed/last/any,cooker,i586/srpms.rss')->is_success, 'Request should succeed' );
done_testing();
