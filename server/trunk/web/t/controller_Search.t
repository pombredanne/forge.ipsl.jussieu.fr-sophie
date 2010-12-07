use strict;
use warnings;
use Test::More;

my $pkgid = '45db73adf5f9ceabc8f9ea1dabccffcc';

BEGIN { use_ok 'Catalyst::Test', 'Sophie' }
BEGIN { use_ok 'Sophie::Controller::Search' }

sub xmlrpcreq {
    my (@xmlargs) = @_;
    my $str = RPC::XML::request->new( @xmlargs )->as_string;

    my $req = HTTP::Request->new( POST => 'http://localhost/rpc' );
    $req->header( 'Content-Length'  => length($str) );
    $req->header( 'Content-Type'    => 'text/xml' );
    $req->content( $str );
    return $req;
}

ok( 
    request( xmlrpcreq('search.rpms.bydate', {}, time - 3600) ),
    "search.rpms.bydate"
);

ok( 
    request( xmlrpcreq('search.rpm.bypkgid', {}, $pkgid) ),
    "search.rpm.bypkgid"
);

ok( 
    request( xmlrpcreq('search.rpm.byname', {}, 'rpm', '>', '0') ),
    "search.rpm.byname"
);

ok( 
    request( xmlrpcreq('search.rpm.bytag', {}, 'name', 'rpm') ),
    "search.rpm.bytag"
);

ok( 
    request( xmlrpcreq('search.rpm.bydep', {}, 'P', 'rpm', '>', '0') ),
    "search.rpm.bydep"
);

ok( 
    request( xmlrpcreq('search.rpm.byfile', {}, '/bin/rpm') ),
    "search.rpm.byfile"
);

ok( 
    request( xmlrpcreq('search.rpm.fuzzy', {}, 'rpm-build') ),
    "search.rpm.fuzzy"
);
ok( 
    request( xmlrpcreq('search.rpm.quick', {}, 'rpm-build') ),
    "search.rpm.quick"
);


ok( 
    request( xmlrpcreq('search.rpm.description', {}, qw'rpm build') ),
    "search.rpm.description"
);

ok( request('/search')->is_success, 'Request should succeed' );
done_testing();
