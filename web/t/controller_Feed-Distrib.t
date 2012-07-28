use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Feed::Distrib' }

my ($dist, $release, $arch) = qw(Mandriva cooker i586);

ok( request('/feed/distrib')->is_success, '/feed/distrib' );
ok( request("/feed/distrib/$dist")->is_success, "feed $dist" );
ok( request("/feed/distrib/$dist/$release")->is_success, "feed $dist/$release" );
ok( request("/feed/distrib/$dist/$release/$arch")->is_success, "feed $dist/$release/$arch" );
done_testing();
