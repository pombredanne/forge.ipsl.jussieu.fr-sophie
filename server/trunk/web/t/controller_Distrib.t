use strict;
use warnings;
use Test::More;
require RPC::XML;
use HTTP::Request;

# know existing data:
my $distribution = 'Mandriva';
my $release = 'cooker';
my $arch = 'i586';

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
done_testing();
