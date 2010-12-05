use strict;
use warnings;
use Test::More;
require RPC::XML;
use HTTP::Request;

# know existing data:
my $distribution = 'Mandriva';
my $release = '2010.1';
my $arch = 'x86_64';
my $media = 'main-release';
my $pkgid = '45db73adf5f9ceabc8f9ea1dabccffcc';
my $rpmname = 'rpm';

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Distrib' }

sub xmlrpcreq {
    my (@xmlargs) = @_;
    my $str = RPC::XML::request->new( @xmlargs )->as_string;

    my $req = HTTP::Request->new( POST => 'http://localhost/rpc' );
    $req->header( 'Content-Length'  => length($str) );
    $req->header( 'Content-Type'    => 'text/xml' );
    $req->content( $str );
    return $req;
}

ok( request('/distrib')->is_success, 'Request should succeed' );
ok( request("/distrib/$distribution")->is_success, 'Request should succeed' );
ok( request( xmlrpcreq('distrib.list') ), "XMLRPC");
ok( request( xmlrpcreq('distrib.list', $distribution) ), "XMLRPC");
ok( request("/distrib/$distribution/$release")->is_success, 'Request should succeed' );
ok( request("/distrib/$distribution/$release/$arch")->is_success, 'Request should succeed' );
ok( request("/distrib/$distribution/$release/$arch/media")->is_success, 'Request should succeed' );
ok(
    request("/distrib/$distribution/$release/$arch/media/$media/by-pkgid/$pkgid")
    ->is_success, "request media/pkgid");
ok(
    request("/distrib/$distribution/$release/$arch/media/$media/by-pkgid/$pkgid/deps")
    ->is_success, "request media/pkgid/deps");
ok(
    request("/distrib/$distribution/$release/$arch/media/$media/by-pkgid/$pkgid/files")
    ->is_success, "request media/pkgid/files");
ok(
    request("/distrib/$distribution/$release/$arch/media/$media/by-pkgid/$pkgid/changelog")
    ->is_success, "request media/pkgid/changelog");

ok(
    request("/distrib/$distribution/$release/$arch/rpms/$rpmname")
    ->is_success, "request rpms/$rpmname");
ok(
    request("/distrib/$distribution/$release/$arch/srpms/$rpmname")
    ->is_success, "request srpms/$rpmname");

ok(
    request("/distrib/$distribution/$release/$arch/by-pkgid/$pkgid")
    ->is_success, "request distrib bypkgid");

done_testing();
