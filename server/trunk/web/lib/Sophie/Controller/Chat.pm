package Sophie::Controller::Chat;
use Moose;
use namespace::autoclean;
use Getopt::Long;
use Text::ParseWords;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Chat - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;


}

sub message : XMLRPC {
    my ($self, $c, $contexts, $message, @msgargs) = @_;
    
    my $reqspec = {};

    foreach my $co (ref $contexts ? @$contexts : $contexts) {
        if (ref($co) eq 'HASH') {
            foreach (keys %$co) {
                $reqspec->{$_} = $co->{$_};
            }
        } else {
            if (my $coo = $c->forward('/user/fetchdata', [ $co ])) {
                foreach (keys %$coo) { 
                    $reqspec->{$_} = $coo->{$_};
                }
            }
        }
    }

    my ($cmd, @args) = @msgargs
        ? ($message, @msgargs)
        : Text::ParseWords::shellwords($message);

    if ($c->get_action( $cmd, '/chat/cmd' )) {
        return $c->go('/chat/cmd/' . $cmd, [ $reqspec, @args ]);
    } else {
        $c->stash->{xmlrpc} = {
            error => 'No such command',
        };
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
