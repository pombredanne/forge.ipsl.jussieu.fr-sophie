package Sophie::Controller::Rpms;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Rpms - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Rpms in Rpms.');
}

sub tags : XMLRPCLocal {
    my ( $self, $c, $pkgid ) = @_;
    $c->stash->{pkgid} = $c->model('Base::Rpms')->search(pkgid => $pkgid)->next;
    $c->stash->{xmlrpc} = $c->stash->{pkgid}->summary;
}

sub rpms : Chained : PathPart {
    my ( $self, $c, $pkgid ) = @_;
    $c->stash->{pkgid} = $c->model('Base::Rpms')->search(pkgid => $pkgid)->next;
    $c->log->debug('rpms ' . $c->stash->{pkgid});
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
