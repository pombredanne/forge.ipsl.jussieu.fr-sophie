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

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->req->param('page')) {
        $c->req->params->{search} = $c->session->{search};
    }

    if ($c->req->param('search')) {
        $c->session->{search} = $c->req->param('search');
        $c->forward('quick', [ undef, split(/\s/, $c->req->param('search')) ]);
        my $pager = $c->stash->{rs}->pager;
        $c->stash->{pager} = $pager;
        $c->stash->{xmlrpc} = [
            $c->stash->{rs}->get_column('pkgid')->all
        ];
    }
}

sub adv :Local {
    my ($self, $c) = @_;
}

sub search_param : Private {
    my ($self, $c) = @_;
    my $r = {
        rows => Sophie->config()->{'max_reply'} || 20000,
        order_by => [ 'name', 'evr using >>', 'issrc' ],
        select => [ 'pkgid' ],
    };
    if (!$c->req->xmlrpc->method) {
        $r->{page} = $c->req->param('page') || 1;
        $r->{rows} = 20;
    }
    return $r;
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
                    ? (version => $searchspec->{release})
                    : ()
            }
        )->search_related('Arch',
            {
                $searchspec->{arch}
                    ? (arch => $searchspec->{arch})
                    : ()
            }
        )->search_related('Medias',
            {
                ($searchspec->{media} ? (label => $searchspec->{media}) : ()),
                ($searchspec->{media_group}
                    ? (group_label => $searchspec->{media_group}) 
                    : ()),
            }
        )->search_related('MediasPaths')
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
        $c->forward('search_param'),
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
        $c->forward('search_param'),
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
        $c->forward('search_param'),
    )->get_column('pkgid')->all ]
}

sub fuzzy : XMLRPCPath('/search/rpm/fuzzy') {
    my ($self, $c, $searchspec, $name) = @_;

    my $deprs = $c->model('Base')->resultset('Deps')->search(
        { deptype => 'P', depname => { '~*' => $name } }
    )->get_column('pkgid');

    $c->stash->{rs} = 

        $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { -or => [
                    { name => 
                        { '~*' => $name, },
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
        $c->forward('search_param'),
    );
    
    if ($c->req->xmlrpc->method) {
        $c->stash->{xmlrpc} = [ 
            $c->stash->{rs}->get_column('pkgid')->all
        ];
    }
}

sub quick : XMLRPCPath('/search/rpm/quick') {
    my ($self, $c, $searchspec, @keywords) = @_;
    my $tsquery = join(' & ', map { $_ =~ s/ /\\ /g; $_ } @keywords);
    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
            {
                -or => [
                    { -nest => \[
                        "to_tsvector('english', description) @@ to_tsquery(?)",
                        [ plain_text => $tsquery],
                    ], },
                    {
                    name => [ @keywords ],
                    },
                ],
            (exists($searchspec->{src})
                ? (issrc => $searchspec->{src} ? 1 : 0)
                : ()),
            pkgid =>
            { IN => $c->forward('distrib_search', [ $searchspec
                    ])->get_column('pkgid')->as_query, }, 


        },
        {
            %{$c->forward('search_param')},
        },
    );
    if ($c->req->xmlrpc->method) {
        $c->stash->{xmlrpc} = [ 
            $c->stash->{rs}->get_column('pkgid')->all
        ];
    }
}

sub description : XMLRPCPath('/search/rpm/description') {
    my ($self, $c, $searchspec, @keywords) = @_;
    my $tsquery = join(' & ', map { $_ =~ s/ /\\ /g; $_ } @keywords);
    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
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
            %{$c->forward('search_param')},
            select => [ 
                "ts_rank_cd(to_tsvector('english', description),to_tsquery(?)) as rank",
                'pkgid'
            ],
            bind => [ $tsquery ], 
            order_by => [ 'rank desc', 'name', 'evr using >>', 'issrc' ],
        },
    );
    if ($c->req->xmlrpc->method) {
        $c->stash->{xmlrpc} = [ 
            $c->stash->{rs}->get_column('pkgid')->all
        ];
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
