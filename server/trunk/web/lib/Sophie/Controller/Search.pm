package Sophie::Controller::Search;
use Moose;
use namespace::autoclean;
use Sophie;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Search - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

my $search_param = {
    rows => Sophie->config()->{'max_reply'} || 20000,
    order_by => [ 'name', 'evr using >>', 'issrc' ],
    select => [ 'pkgid' ],
};

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Search in Search.');
}

sub distrib_search : Private {
    my ( $self, $c, $searchspec ) = @_;

    return $c->model('Base')->resultset('Distribution')
        ->search(
            {
                $searchspec->{distribution}
                    ? (name => $searchspec->{distribution})
                    : ()
            }
        )->search_related('Release',
            {
                $searchspec->{release}
                    ? (release => $searchspec->{release})
                    : ()
            }
        )->search_related('Arch',
            {
                $searchspec->{arch}
                    ? (arch => $searchspec->{arch})
                    : ()
            }
        )->search_related('Medias')
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles');
}

sub bytag : XMLRPCPath('/search/rpm/bytag') {
    my ( $self, $c, $searchspec, $tag, $tagvalue ) = @_;

    my $tagrs = $c->model('Base')->resultset('Tags')
        ->search({ tagname => lc($tag), value => $tagvalue})
        ->get_column('pkgid');
    $c->stash->{xmlrpc} = [ $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [ 
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { pkgid => 
                    { IN => $tagrs->as_query, },
                },
                { pkgid =>
                    { IN => $c->forward('distrib_search', [ $searchspec
                        ])->get_column('pkgid')->as_query, }, 
                },
            ]     
        },
        $search_param,
    )->get_column('pkgid')->all ]

}

sub bydep : XMLRPCPath('/search/rpm/bydep') {
    my ( $self, $c, $searchspec, $deptype, $depname, $depsense, $depevr ) = @_;

    my $deprs = $c->model('Base')->resultset('Deps')->search(
        {
            deptype => $deptype,
            depname => $depname,
            ($depsense
                ? (-nest => \[
                    'rpmdepmatch(flags, evr, rpmsenseflag(?), ?)',
                    [ plain_text => $depsense],
                    [ plain_text => $depevr ]
                ])
            : ()),
        }
    )->get_column('pkgid');
    $c->stash->{xmlrpc} = [ $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [ 
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { pkgid => 
                    { IN => $deprs->as_query, },
                },
                { pkgid =>
                    { IN => $c->forward('distrib_search', [ $searchspec
                        ])->get_column('pkgid')->as_query, }, 
                },
            ]     
        },
        $search_param,
    )->get_column('pkgid')->all ]
}

sub byfile : XMLRPCPath('/search/rpm/byfile') {
    my ( $self, $c, $searchspec, $file) = @_;
    my ($dirname, $basename) = $file =~ m:^(.*/)?([^/]+)$:;

    my $filers = $c->model('Base')->resultset('Files')
    ->search({
            ($dirname
                ? (dirname => $dirname)
                : ()),
            basename => $basename,
        })
    ->get_column('pkgid');
    $c->stash->{xmlrpc} = [ $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [ 
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { pkgid => 
                    { IN => $filers->as_query, },
                },
                { pkgid =>
                    { IN => $c->forward('distrib_search', [ $searchspec
                        ])->get_column('pkgid')->as_query, }, 
                },
            ]     
        },
        $search_param,
    )->get_column('pkgid')->all ]
}

sub fuzzy : XMLRPCPath('/search/rpm/fuzzy') {
    my ($self, $c, $searchspec, $name) = @_;

    my $namers = $c->model('Base')->resultset('Tags')->search(
        { tagname => 'name', value => { '~*' => $name } }
    )->get_column('pkgid');
    my $deprs = $c->model('Base')->resultset('Deps')->search(
        { deptype => 'P', depname => { '~*' => $name } }
    )->get_column('pkgid');

    $c->stash->{xmlrpc} = [ $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { -or => [
                    { pkgid => 
                        { IN => $namers->as_query, },
                    },
                    { pkgid =>
                        { IN => $deprs->as_query, },
                    }, ]
                },
                { pkgid =>
                    { IN => $c->forward('distrib_search', [ $searchspec
                        ])->get_column('pkgid')->as_query, }, 
                },
            ]     
        },
        $search_param,
    )->get_column('pkgid')->all ]
}

sub description : XMLRPCPath('/search/rpm/description') {
    my ($self, $c, $searchspec, @keywords) = @_;
    my $tsquery = join(' & ', map { $_ =~ s/ /\\ /g; $_ } @keywords);
    $c->stash->{xmlrpc} = [ map { $_->get_column('pkgid') } $c->model('Base')->resultset('Rpms')->search(
        {
            -nest => \[
                    "to_tsvector('english', description) @@ to_tsquery(?)",
                    [ plain_text => $tsquery],
                ],
                (exists($searchspec->{src})
                    ? (issrc => $searchspec->{src} ? 1 : 0)
                    : ()),
                pkgid =>
                    { IN => $c->forward('distrib_search', [ $searchspec
                ])->get_column('pkgid')->as_query, }, 
                
          
        },
        {
            %$search_param,
            select => [ 
                "ts_rank_cd(to_tsvector('english', description),to_tsquery(?)) as rank",
                'pkgid'
            ],
            bind => [ $tsquery ], 
            order_by => [ 'rank desc', 'name', 'evr using >>', 'issrc' ],
        },
    )->all ]

}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
