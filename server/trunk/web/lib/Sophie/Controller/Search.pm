package Sophie::Controller::Search;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Search - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Search in Search.');
}

sub bytag : XMLRPCPath('/search/rpm/bytag') {
    my ( $self, $c, $searchspec, $tag, $tagvalue ) = @_;

    @{$c->stash->{xmlrpc}} = $c->model('Base')->resultset('Rpms')->search(
        {
            pkgid => { IN => $c->model('Base')->resultset('Tags')
                ->search({ tagname => $tag, value => $tagvalue})
                ->get_column('pkgid')->as_query }
        }
    )->get_column('pkgid')->all

}

sub bydep : XMLRPCPath('/search/rpm/bydep') {
    my ( $self, $c, $searchspec, $deptype, $depname, $depsense, $depevr ) = @_;

    @{$c->stash->{xmlrpc}} = $c->model('Base')->resultset('Rpms')->search(
        {
            pkgid => { IN => $c->model('Base')->resultset('Deps')
                ->search({
                        deptype => $deptype,
                        depname => $depname,
                        ($depsense
                            ? (-nest => \[
                                'rpmdepmatch(flags, evr, rpmsenseflag(?), ?)',
                                     [ plain_text => $depsense],
                                     [ plain_text => $depevr ]
                                 ])
                            : ()
                        ),
                })
                ->get_column('pkgid')->as_query }
        }
    )->get_column('pkgid')->all

}

sub byfile : XMLRPCPath('/search/rpm/byfile') {
    my ( $self, $c, $searchspec, $file) = @_;
    my ($dirname, $basename) = $file =~ m:^(.*/)?([^/]+)$:;

    @{$c->stash->{xmlrpc}} = $c->model('Base')->resultset('Rpms')->search(
        {
            pkgid => { IN => $c->model('Base')->resultset('Files')
                ->search({
                        ($dirname
                            ? (dirname => $dirname)
                            : ()),
                        basename => $basename,
                })
                ->get_column('pkgid')->as_query }
        }
    )->get_column('pkgid')->all
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
