use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/xml.pl";

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::User::Folder' }

ok( request('/user/folder')->is_success, 'Request should succeed' );
ok( xmlrequest_ok('user.folder.list'), 'RPC user.folder.list');
done_testing();
