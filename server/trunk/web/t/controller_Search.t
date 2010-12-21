use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/xml.pl";

my $pkgid = '45db73adf5f9ceabc8f9ea1dabccffcc';

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Search' }

ok( 
    xmlrequest_ok('search.rpms.bydate', {}, time - 3600),
    "search.rpms.bydate"
);

ok( 
    xmlrequest_ok('search.rpm.bypkgid', {}, $pkgid),
    "search.rpm.bypkgid"
);

ok( 
    xmlrequest_ok('search.rpm.byname', {}, 'rpm', '>', '0'),
    "search.rpm.byname"
);

ok( 
    xmlrequest_ok('search.rpm.bytag', {}, 'name', 'rpm'),
    "search.rpm.bytag"
);

ok( 
    xmlrequest_ok('search.rpm.bydep', {}, 'P', 'rpm', '>', '0'),
    "search.rpm.bydep"
);

ok( 
    xmlrequest_ok('search.rpm.byfile', {}, '/bin/rpm'),
    "search.rpm.byfile"
);

ok( 
    xmlrequest_ok('search.rpm.fuzzy', {}, 'rpm-build'),
    "search.rpm.fuzzy"
);
ok( 
    xmlrequest_ok('search.rpm.quick', {}, 'rpm-build'),
    "search.rpm.quick"
);


ok( 
    xmlrequest_ok('search.rpm.description', {}, qw'rpm build'),
    "search.rpm.description"
);

ok( request('/search')->is_success, 'Request should succeed' );
done_testing();
