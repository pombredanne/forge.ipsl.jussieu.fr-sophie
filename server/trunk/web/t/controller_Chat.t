use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/xml.pl";

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Chat' }

ok( request('/chat')->is_success, 'Request should succeed' );

ok( xmlrequest_ok( 'chat.message', [], "help"), "Can request help");

done_testing();
