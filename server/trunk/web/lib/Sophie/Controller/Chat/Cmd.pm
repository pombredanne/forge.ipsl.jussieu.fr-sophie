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

=head1 BOT COMMAND

=head2 REPLY

=cut

sub _commands {
    my ( $self, $c ) = @_;
    [ grep { m/^[^_]/ } map { $_->name } $self->get_action_methods() ];
}

sub help : XMLRPC {
    my ( $self, $c, $reqspec, @args ) = @_;
    return $c->{stash}->{xmlrpc} = {
        message => [
            'availlable command:',
            join(', ', @{ $self->_commands }),
        ],
    }
}


sub asv : XMLRPC {
    my ( $self, $c ) = @_;
    return $c->stash->{xmlrpc} = {
        message => [ 'Sophie ' . $Sophie::VERSION . ' Chat: ' . q$Rev$ ],
    };
}



=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
