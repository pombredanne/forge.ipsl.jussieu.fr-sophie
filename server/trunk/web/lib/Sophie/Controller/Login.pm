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
    $login ||= $c->req->param('username');
    $password ||= $c->req->param('password');

    if ($login) {
        if ($c->authenticate({
                mail => $login,
                password => $password,
            }
        )) {
            if ($c->req->xmlrpc->is_xmlrpc_request) {
                $c->stash->{xmlrpc} = 'sophie_session=' . $c->sessionid;
            } else {
                warn 'redirect';
                $c->res->redirect($c->uri_for('/'));
            }
        } else {
            if ($c->req->xmlrpc->is_xmlrpc_request) {
                $c->error('invalid login / password');
            }
        }
    }
}

sub invit_login : Local {
    my ($self, $c) = @_;

}

sub logout :Local {
    my ($self, $c) = @_;

    $c->logout;
}

sub create :Local {
    my ($self, $c) = @_;

    warn $c->req->param('valid');
    warn $c->session->{valid_create_user};
    if ((my $valid = $c->req->param('valid')) && $c->req->param('username')) {
       if ($valid == $c->session->{valid_create_user}) {
           my $res = $c->forward('/admin/create_user',
               [
                   $c->req->param('username'),
                   $c->req->param('password'),
               ]
            );
            if ($res) {
               $c->res->redirect($c->uri_for('/login',
                   { username => $c->req->param('username') }
               ));
           }
       }
    }
    my $aa = (0 .. 9)[rand(9)];
    my $bb = (0 .. 9)[rand(9)];
    $c->stash->{valid} = "$aa + $bb";
    $c->session->{valid_create_user} = $aa + $bb;

}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
