use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Search::Rpm' }

ok( request('/search/rpm')->is_success, 'Request should succeed' );
done_testing();
