package Sophie::Controller::Search::Dep;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Search::Dep - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Search::Dep in Search::Dep.');
}

sub match : Private {
    my ($self, $c, $searchspec, $deptype, $depname, $depsense, $depevr) = @_;
    $c->stash->{xmlrpc} = [ 
        map { { $_->get_columns } }
        $c->forward(
        '/search/deps_rs', [ 
            $searchspec, $deptype, $depname,
            $depsense, $depevr 
        ],
    )->all ];
}

sub match_rpc : XMLRPCPath('match') {
    my ($self, $c, $searchspec, $deptype, $depname, $depsense, $depevr) = @_;

    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);
    $c->stash->{rs} = $c->forward(
        '/search/deps_rs', [ 
            $searchspec, $deptype, $depname,
            $depsense, $depevr 
        ],
    );

    $c->stash->{column} = [ qw(name sense evr flags pkgid) ];
}


=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
