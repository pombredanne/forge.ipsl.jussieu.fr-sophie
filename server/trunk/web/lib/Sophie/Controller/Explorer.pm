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

    if (grep { exists($c->req->params->{$_}) } qw(distribution release arch)) {
        $c->session->{explorer} = {
            distribution => $c->req->param('distribution') || undef,
            release => $c->req->param('release') || undef,
            arch => $c->req->param('arch') || undef,
        };
    }
    $c->session->{__explorer} = $c->session->{explorer};

    $c->stash->{path} = join('/', grep { $_  } @args);
    for(my $i=0; $i < @args; $i++) {
        push(@{$c->stash->{eachpath}}, { dir=>$args[$i], path =>join('/',
                    @args[0 .. $i] ) });
    }
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
