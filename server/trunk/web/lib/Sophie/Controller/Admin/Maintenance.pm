package Sophie::Controller::Admin::Maintenance;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Admin::Maintenance - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub delete_expired_sessions :XMLRPC {
    my ($self, $c) = @_;

    $c->delete_expired_sessions;

    $c->stash->{xmlrpc} = 'Done';
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
