use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/xml.pl";

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Chat::Cmd' }

foreach (qw(version v packager p arch a buildfrom)) {
    ok(
        xmlrequest_ok("chat.cmd.$_", {}, "rpm"),
        "XML::RPC chat.cmd.$_"
    );
}

done_testing();
