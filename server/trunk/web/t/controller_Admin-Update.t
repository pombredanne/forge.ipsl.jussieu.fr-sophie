use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Sophie';
use Sophie::Controller::Admin::Update;

ok( request('/admin/update')->is_success, 'Request should succeed' );
done_testing();
