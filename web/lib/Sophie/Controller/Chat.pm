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

    $c->stash->{template} = 'chat/index.html';
    if (my $cmd = $c->req->param('cmd')) {
        $c->forward('message', [
            [{
                distribution => $c->req->param('distribution') || undef,
                release => $c->req->param('release') || undef,
                arch => $c->req->param('arch') || undef,
                max_line => 30,
                no_paste => 1,
            }], $cmd ]);
    }

}

sub viewpaste :Path :Args(1) {
    my ($self, $c, $pasteid) = @_;

    $c->forward('get_paste', [ $pasteid ]);
    if (! $c->stash->{xmlrpc}) {
        $c->go('/404/index');
    }
}


sub update_statistic : Private {
    my ($self, $c, $cmd) = @_;

    my $stat = $c->model('Base::ChatStat')->find_or_create({
        cmd => $cmd,
        day => 'now()',
    });
    $stat->update({ count => ($stat->count || 0) + 1 });
    $c->model('Base')->storage->dbh->commit;
}


sub message : XMLRPC {
    my ($self, $c, $contexts, $message, @msgargs) = @_;
    
    my $reqspec = {};
    my @contexts = grep { $_ } (
        $c->user_exists
        ? ( 'default' )
        : (),
        (ref $contexts
            ? (@$contexts)
            : ($contexts)
        ),
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

    if (! ref($contexts[-1])) {
        $reqspec->{from} = $contexts[-1];
    }

    my ($cmd, @args) = @msgargs
        ? ($message, @msgargs)
        : Text::ParseWords::shellwords($message);

    if ($c->get_action( $cmd, '/chat/cmd' )) {
        return $c->go('/chat/cmd/' . $cmd, [ $reqspec, @args ]);
    } else {
        return $c->forward('err_no_cmd', []);
    }
}

=head2 err_no_cmd

Return the 'no such command error'.

=cut

sub err_no_cmd : Private {
    my ($self, $c ) = @_;
    return $c->stash->{xmlrpc} = {
        error => 'No such command',
    };
}

sub paste : XMLRPCLocal {
    my ($self, $c, $title, $text) = @_;

    if ($c->user_exists) {
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
        return $c->stash->{xmlrpc} = $id;
    } else {
        return $c->stash->{xmlrpc} = undef;
    }
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
