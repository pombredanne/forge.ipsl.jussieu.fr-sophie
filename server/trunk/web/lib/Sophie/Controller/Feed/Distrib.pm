package Sophie::Controller::Feed::Distrib;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Feed::Distrib - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Feed::Distrib in Feed::Distrib.');
}

sub distrib :Path :Args {
    my ( $self, $c, $distrib, $release, $arch ) = @_;
    $c->stash->{dist}{distribution} = $distrib;
    $c->stash->{dist}{release} = $release;
    $c->stash->{dist}{arch} = $arch;

    $c->forward('/distrib/exists', [ $c->stash->{dist} ]) or
        $c->go('/404/index');
}

sub end : Private {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'Rss';
    $c->stash->{rss} = $c->model('Rss');
    foreach my $item (@{ $c->forward(
        '/search/rpms/bydate',
        [
            {
                %{ $c->stash->{dist} || {}},
                src => 1,
                rows => 50,
            }, time - (3600 * 24 * 30)
        ]
    ) }) {
        my $info = $c->forward('/rpms/basicinfo', [ $item->{pkgid} ]);
        $c->stash->{rss}->add_item(
            title => $item->{filename},
            permaLink => $c->uri_for('/distrib', $item->{distribution},
                $item->{release}, $item->{arch}, 'by-pkgid', $item->{pkgid}),
            guid => $item->{pkgid},
            description => "In " . join('/', $item->{distribution},
                $item->{release}, $item->{arch}) . ":\n" .
                $info->{description},
        );
    }

    $c->forward('/feed/end');
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
