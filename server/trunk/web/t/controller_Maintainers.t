use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/xml.pl";

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Maintainers' }

ok(
    xmlrequest_ok('maintainers.byrpm', 'rpm'),
    "XML maintainers.byrpm"
);

ok(
    request('/maintainers/rpm?json=1')->is_success,
    "/maintainers/rpm / JSON"
);

done_testing();
