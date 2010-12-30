package Sophie::Controller::Feed::Last;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Feed::Last - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub index :Path :Args(2) {
    my ( $self, $c, $dist, $feed ) = @_;
    
    my @args = split(',', $dist);
    unshift(@args, '') if (@args == 2);
    foreach(@args) {
        $_ = undef if $_ eq 'any'
    };
    my $distspec = {
       distribution => $args[0],
       release => $args[1],
       arch => $args[2],
    };
    $c->forward('/distrib/exists', [ $distspec ]) or
        $c->go('/404/index');
    $c->stash->{dist} = $distspec;

    for ($feed) {
        /^rpms\./  and do { $c->stash->{src} = 0; last };
        /^srpms\./ and do { $c->stash->{src} = 1; last };
        /^all\./   and do { last; };
        $c->go('/404/index');
    }
    #require Data::Dumper;
    #$c->response->body($dist .' ' . $feed . ' ' . Data::Dumper::Dumper($distspec));

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
                src => $c->stash->{src},
                rows => 50,
            }, 1
        ]
    ) }) {
        my $info = $c->forward('/rpms/basicinfo', [ $item->{pkgid} ]);
        $c->stash->{rss}->add_item(
            title => $item->{filename},
            permaLink => $c->uri_for('/rpms', $item->{pkgid}),
            guid => $item->{pkgid},
            description => $info->{description},
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
