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

    $c->response->body('Matched Sophie::Controller::Chat in Chat.');
}


sub message : XMLRPC {
    my ($self, $c, $contexts, $message) = @_;
    
    my $reqspec = {};

    foreach my $co (ref $contexts ? @$contexts : $contexts) {
        warn $co;
        if (ref $co) {
            foreach (keys %$co) {
                $reqspec->{$_} = $co->{$_};
            }
        } else {
            if (my $coo = $c->forward('/user/fetchdata', $co)) {
                foreach (keys %$coo) { 
                    $reqspec->{$_} = $coo->{$_};
                }
            }
        }
    }

    $c->stash->{xmlrpc} = $c->forward($c->model('Chat'), [ $reqspec, $message ]); 
    
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
