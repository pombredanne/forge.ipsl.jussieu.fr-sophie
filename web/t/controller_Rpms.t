use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/xml.pl";

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Rpms' }

my $pkgid = '45db73adf5f9ceabc8f9ea1dabccffcc';

ok( request('/rpms')->is_redirect, 'Request should succeed' );
ok( request("/rpms/$pkgid")->is_success, 'Request a pkgid should succeed' );
ok( request("/rpms/$pkgid/deps")->is_success, 'Request a pkgid/deps should succeed' );
ok( request("/rpms/$pkgid/files")->is_success, 'Request a pkgid/files should succeed' );
ok( request("/rpms/$pkgid/changelog")->is_success, 'Request a pkgid/changelog should succeed' );
ok( request("/rpms/$pkgid/location")->is_success, 'Request a pkgid/location should succeed' );
ok( request("/rpms/$pkgid/scriptlet")->is_success, 'Request a pkgid/scriptlet should succeed' );

ok( xmlrequest_ok('rpms.basicinfo', $pkgid), 'XMLRPC rpms.basicinfo' );
ok( request("/rpms/$pkgid/basicinfo?json"), "rpms/basicinfo?json" );
ok( xmlrequest_ok('rpms.info', $pkgid), 'XMLRPC rpms.basicinfo' );
ok( request("/rpms/$pkgid/info?json"), "rpms/basicinfo?json" );
ok( xmlrequest_ok('rpms.dependency', $pkgid, 'R'), 'XMLRPC rpms.dependency' );
ok( request("/rpms/$pkgid/dependency/R?json"), "rpms/dependency?json" );

done_testing();
