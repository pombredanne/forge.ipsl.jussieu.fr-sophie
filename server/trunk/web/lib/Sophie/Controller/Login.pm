package Sophie::Controller::Login;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) :XMLRPCPath('/login') {
    my ( $self, $c, $login, $password ) = @_;

    if ($c->authenticate({
            mail => $login || $c->req->param('username'),
            password => $password || $c->req->param('password'),
        }
    )) {
        if ($c->req->xmlrpc->is_xmlrpc_request) {
            $c->stash->{xmlrpc} = 'sophie_session=' . $c->sessionid;
        } else {
            $c->res->redirect('/');
        }
    } else {
        if ($c->req->xmlrpc->is_xmlrpc_request) {
            $c->error('invalid login / password');
        }
    }
}


=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
