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
                $c->res->redirect($c->uri_for('/'));
            }
        } else {
            if ($c->req->xmlrpc->is_xmlrpc_request) {
                $c->error('invalid login / password');
            } else {
                $c->stash->{error} = 'Invalid login / password';
            }
        }
    }
}

sub invit_login : Local {
    my ($self, $c) = @_;

}

sub create_request : Private {
    my ($self, $c, $mail) = @_;

    my $valid_code = join('', map { sprintf("%02x", rand(256)) } (0 .. 15));

    $c->model('Base::AccountRequest')->create({
            mail => $mail,
            valid_code => $valid_code,
            ip_address => $c->req->address,
    });
    $c->model('Base')->storage->dbh->commit;

    return $valid_code;
}

sub create :Local {
    my ($self, $c) = @_;

    if ((my $valid = $c->req->param('valid')) && $c->req->param('username')) {
       # create a login request
       my $valid_code = $c->forward('create_request', [ $c->req->param('username') ],);

       if ($valid == $c->session->{valid_create_user}) {
           $c->stash->{email} = {
               header => [
                   to      => $c->req->param('username'),
                   from    => 'sophie@zarb.org',
                   subject => 'Sophie.zarb.org confirm request',
               ],
               body    => "
Someone, hopefully you, request an account on Sophe web site.

To complete your subscription follow the link bellow:

" . $c->uri_for('/login/confirm', { id => $valid_code }) . "

If this is an error, simply ignore this mail.

",
           };
           $c->forward( $c->view('Email') );
        }
    }
    my $aa = (0 .. 9)[rand(9)];
    my $bb = (0 .. 9)[rand(9)];
    $c->stash->{valid} = "$aa + $bb";
    $c->session->{valid_create_user} = $aa + $bb;
}

sub confirm :Local {
    my ($self, $c) = @_;

    my $reqid = $c->req->param('id');

    my $request = $c->model('Base::AccountRequest')->find(
        {
            valid_code => $reqid,
        });
    if (!$request) {
        # ERR
    }
    $c->stash->{email} = $request->mail;

    if ($c->req->param('password')) {
       my $res = $c->forward('/admin/create_user',
           [
               $request->mail,
               $c->req->param('password'),
           ]
        );
        if ($res) {
           $request->delete;
           $c->model('Base')->storage->dbh->commit;
           # TODO authenticate user directly
           $c->res->redirect($c->uri_for('/login',
               { username => $request->mail }
           ));
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
