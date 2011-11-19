package Sophie::Controller::User;
use Moose;
use namespace::autoclean;
use MIME::Base64;
use Storable qw/nfreeze thaw/;
use YAML;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::User in User.');
}

sub session : XMLRPC {
    my ( $self, $c ) = @_;

    $c->session;
    $c->stash->{xmlrpc} = 'sophie_session=' . $c->sessionid;
}

sub fetch_user_data : Private {
    my ( $self, $c, $user, $dataname ) = @_;

    if (my $rs = $c->model('Base')->resultset('Users')->search(
        { mail => $user, }
    )->search_related(
        'UsersData', { varname => $dataname }
    )->next) {
        $c->stash->{xmlrpc} = thaw( decode_base64( $rs->get_column('value') ) );
    } else {
        $c->stash->{xmlrpc} = {};
    }

    return $c->stash->{xmlrpc};
}


sub fetchdata : XMLRPC {
    my ( $self, $c, $dataname ) = @_;

    $c->user or return {};

    return $c->forward('fetch_user_data', [ $c->user->mail || '', $dataname ]);
}

sub dumpdata : XMLRPC {
    my ( $self, $c, $dataname ) = @_;

    return $c->stash->{xmlrpc} = YAML::freeze(
        $c->forward('fetchdata', [ $dataname ])
    );
}

sub set_user_data : Private {
    my ( $self, $c, $user, $dataname, $data ) = @_;

    my $User = $c->model('Base')->resultset('Users')->find( { mail => $user } )
        or return;

    $c->model('Base')->resultset('UsersData')->update_or_create({
        Users => $User,
        varname => $dataname,
        value => encode_base64( nfreeze($data) ),
    });
    $c->model('Base')->storage->dbh->commit;
    return $c->stash->{xmlrpc} = 'Updated';
}

sub setdata : XMLRPC {
    my ( $self, $c, $dataname, $data ) = @_;

    return $c->forward('set_user_data', [ $c->user->mail, $dataname, $data ]);
}

sub loaddata : XMLRPC {
    my ( $self, $c, $dataname, $data ) = @_;

    $c->forward('setdata', [ $dataname, YAML::thaw($data) ]);
}

sub update_data : XMLRPC {
    my ( $self, $c, $dataname, $data ) = @_;
    $c->forward('update_user_data', [ $c->user->mail || '', $dataname, $data ]);
}

sub update_user_data : Private {
    my ( $self, $c, $user, $dataname, $data ) = @_;

    my $prev_data = $c->forward('fetch_user_data',
        [ $user || '', $dataname ]
    ) || {};

    foreach (keys %$data) {
        if (defined($data->{$_})) {
            $prev_data->{$_} = $data->{$_};
        } else {
            delete($prev_data->{$_});
        }
    }

    $c->forward('set_user_data', [ $user, $dataname, $prev_data ]);
}

sub set_user_password : Private {
    my ($self, $c, $user, $clear_password ) = @_;

    my @random = (('a'..'z'), ('A'..'Z'), (0 .. 9));
    my $salt = join('', map { $random[rand(@random)] } (0..5));

    my $pass = crypt($clear_password, '$1$' . $salt);
    if (my $rsuser = $c->model('Base::Users')->find({
            mail => $user,
        }
    )) {
        $rsuser->update({ password => $pass });
        $c->model('Base')->storage->dbh->commit;
        return $c->stash->{xmlrpc} = 'Password changed for user ' . $user;
    } else {
        $c->error( 'No such user' );
    }
}

=head2 user.set_password( PASSWORD )

Change the password for the current user to password C<PASSWORD>.

The change take effect immediately, so user must login again with the new
password to continue to use the website.

The password is stored internally crypted using UNIX MD5 method.

=cut

sub set_password : XMLRPC {
    my ( $self, $c, $clear_password ) = @_;

    $c->forward('set_user_password', [ $c->user->mail, $clear_password ]);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
