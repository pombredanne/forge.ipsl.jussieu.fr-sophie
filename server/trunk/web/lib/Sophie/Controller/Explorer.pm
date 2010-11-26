package Sophie::Controller::Explorer;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Explorer - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path {
    my ( $self, $c, @args ) = @_;

    $c->stash->{path} = join('/', grep { $_  } @args);
    $c->stash->{dirurl} = $c->uri_for('/0explorer/dir',
        $c->stash->{path} ?
            ($c->stash->{path})
        : ()
    );
    $c->stash->{fileurl} = $c->uri_for('/0explorer/file',
        $c->stash->{path} ?
            ($c->stash->{path})
        : ()
    );
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
