use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Rpms' }

my $pkgid = '45db73adf5f9ceabc8f9ea1dabccffcc';

ok( request('/rpms')->is_success, 'Request should succeed' );
ok( request("/rpms/$pkgid")->is_success, 'Request a pkgid should succeed' );
ok( request("/rpms/$pkgid/deps")->is_success, 'Request a pkgid/deps should succeed' );
ok( request("/rpms/$pkgid/files")->is_success, 'Request a pkgid/files should succeed' );
ok( request("/rpms/$pkgid/changelog")->is_success, 'Request a pkgid/changelog should succeed' );
done_testing();
