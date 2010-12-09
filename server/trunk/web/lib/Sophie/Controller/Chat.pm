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

sub viewpaste :Path :Args(1) {
    my ($self, $c, $pasteid) = @_;

    $c->forward('get_paste', [ $pasteid ]);
    if (! $c->stash->{xmlrpc}) {
        $c->go('/404/index');
    }
}

sub message : XMLRPC {
    my ($self, $c, $contexts, $message, @msgargs) = @_;
    
    my $reqspec = {};
    my @contexts = grep { $_ } (
        $c->user_exists
        ? ( 'default',
            (ref $contexts
                ? (@$contexts)
                : ($contexts)
            ),
        )
        : ()
    );

    foreach my $co (@contexts) {
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

sub paste : XMLRPCLocal {
    my ($self, $c, $title, $text) = @_;

    my @char = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
    my $id = join('', map { $char[rand(@char)] } (0..7));
    $c->model('Base::ChatPaste')->create(
        {
            id => $id,
            user_id => $c->model('Base::Users')->find(
                { mail => $c->user->mail })->ukey,
            title => $title,
            reply => $text,
        }
    );
    $c->model('Base')->storage->dbh->commit;
    $c->stash->{xmlrpc} = $id;
}

sub get_paste : XMLRPCLocal {
    my ($self, $c, $id) = @_;

    my $paste = $c->model('Base::ChatPaste')->find(
            { id => $id, },
            { select => [ qw(whenpaste title reply) ], }
        );
    if ($paste) {
        return $c->stash->{xmlrpc} = { $paste->get_columns };
    } else {
        return $c->stash->{xmlrpc} = undef;
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
