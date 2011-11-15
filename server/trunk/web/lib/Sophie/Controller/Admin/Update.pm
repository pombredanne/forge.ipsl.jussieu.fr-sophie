package Sophie::Controller::Admin::Update;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Admin::Update - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub begin : Pivate {}

sub paths :XMLRPC {
    my ($self, $c) = @_;

    return $c->stash->{xmlrpc} = [
    map { 
        { 
        path => $_->get_column('path'),
        id   => $_->get_column('d_path_key'),
        } 
    } $c->model('Base')->resultset('Paths')->search(
        {},
        {
            select => [ qw(path d_path_key) ],
        }
    )->all ]
}

sub paths_to_update : XMLRPC {
    my ($self, $c) = @_;

    return $c->stash->{xmlrpc} = [
    map { 
        { 
        path => $_->get_column('path'),
        id   => $_->get_column('d_path_key'),
        } 
    } $c->model('Base')->resultset('Paths')->search(
        {
            -or => [
                { updated => [ 
                    undef,
                    \[ " < now() - '24 hours'::interval" ],
                ], },
                { needupdate => 'true' },
            ]
        },
        {
            select => [ qw(path d_path_key) ],
            order_by => [ 'updated' ],
        }
    )->all ]
}

sub set_path_needupdate : XMLRPC {
    my ($self, $c, @paths) = @_;

    warn "rufhruef";
    #$self->model('Base')->txn_do(
    #    sub {
            foreach my $path (@paths) {
                warn $path;
                my $p = $c->model('Base::Paths')->find(
                    { path => $path }
                ) or next;
                $p->update(
                    {
                        needupdate => 'true',
                    }
                );
            }
            $c->model('Base')->storage->dbh->commit;
            return 1;
    #    }
    #);

    return $c->stash->{xmlrpc} = 1;
}


=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
