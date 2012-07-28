use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::0Explorer' }

ok( request('/0explorer/file?json')->is_success, '/file Json Request should succeed' );
ok( request('/0explorer/file/bin?json')->is_success, '/file/bin Json Request should succeed' );
ok( request('/0explorer/dir?json')->is_success, '/dir JsonRequest should succeed' );
ok( request('/0explorer/dir/bin?json')->is_success, '/dir/bin JsonRequest should succeed' );
done_testing();
