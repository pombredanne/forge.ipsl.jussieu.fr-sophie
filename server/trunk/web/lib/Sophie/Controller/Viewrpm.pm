package Sophie::Controller::Viewrpm;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Viewrpm - Catalyst Controller

=head1 DESCRIPTION

This controller exists in sophie 2.0 for compatibility with Sophie 1.X.

Any /viewrpm is redirected to /rpms.

=head1 METHODS

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->res->redirect($c->uri_for('/rpms'));
}

sub viewrpm :Path :Args {
    my ($self, $c, $pkgid, @args) = @_;

    $c->res->redirect($c->uri_for('/rpms', $pkgid, @args));
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
