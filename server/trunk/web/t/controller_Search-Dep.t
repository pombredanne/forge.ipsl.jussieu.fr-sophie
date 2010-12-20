use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Search::Dep' }

# ok( request('/search/dep')->is_success, 'Request should succeed' );
done_testing();
