package Sophie::Controller::Chat::Cmd;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Chat::Cmd - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub help : XMLRPC {
    my ( $self, $c, $reqspec, @args ) = @_;
    return $c->{stash}->{xmlrpc} = [ grep { m/^[^_]/ } map { $_->name } $self->get_action_methods() ];
}


sub me : XMLRPC {
}



=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
