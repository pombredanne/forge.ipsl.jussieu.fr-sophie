package Sophie::Controller::User;
use Moose;
use namespace::autoclean;
use MIME::Base64;
use Storable qw/nfreeze thaw/;

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

sub fetch_user_data : Private {
    my ( $self, $c, $user, $dataname ) = @_;

    if (my $rs = $c->model('Base')->resultset('Users')->search(
        mail => $user,
    )->search_related(
        'UsersData', { varname => $dataname }
    )->next) {
        $c->stash->{xmlrpc} = thaw( decode_base64( $rs->get_column('value') ) );
    } else {
        $c->stash->{xmlrpc} = '';
    }

    return $c->stash->{xmlrpc};
}


sub fetchdata : XMLRPC {
    my ( $self, $c, $dataname ) = @_;

    $c->user or return {};

    return $c->forward('fetch_user_data', [ $c->user->mail || '', $dataname ]);
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
}

sub update_data : XMLRPC {
    my ( $self, $c, $user, $dataname, $data ) = @_;
    $c->forward('update_user_data', [ $c->user->mail || '', $dataname, $data ]);
}

sub update_user_data : Private {
    my ( $self, $c, $user, $dataname, $data ) = @_;

    my $prev_data = $c->forward('fetch_user_data',
        [ $user || '', $dataname ]
    ) || {};

    foreach (keys %$data) {
        $prev_data->{$_} = $data->{$_};
    }

    $c->forward('set_user_data', [ $user, $dataname, $prev_data ]);
}

sub setdata : XMLRPC {
    my ( $self, $c, $dataname, $data ) = @_;

    return $c->forward('set_user_data', [ $c->user->mail, $dataname, $data ]);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
