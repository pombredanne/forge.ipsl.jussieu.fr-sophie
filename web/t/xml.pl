use strict;
use warnings;
use RPC::XML::Parser;
use HTTP::Request;

sub xmlrpcreq {
    my (@xmlargs) = @_;
    my $str = RPC::XML::request->new( @xmlargs )->as_string;

    my $req = HTTP::Request->new( POST => 'http://localhost/rpc' );
    $req->header( 'Content-Length'  => length($str) );
    $req->header( 'Content-Type'    => 'text/xml' );
    $req->content( $str );
    return $req;
}

sub xmlrequest {
    my @args = @_;

    my $res = request(xmlrpcreq(@args));
    $res->is_success or return;

    my $data = RPC::XML::Parser->new->parse( $res->content )->value->value;

    return $data;
}

sub xmlrequest_ok {
    my (@args) = @_;
    my $data = xmlrequest(@args) or return;

    if (ref $data eq 'HASH') {
        exists($data->{faultString}) and return;
    }

    1;
}

1;
