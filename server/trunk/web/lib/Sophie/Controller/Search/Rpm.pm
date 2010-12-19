package Sophie::Controller::Search::Rpm;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Search::Rpm - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Search::Rpm in Search::Rpm.');
}

sub bypkgid : Private {
    my ( $self, $c, $searchspec, $pkgid ) = @_;
    
    $c->stash->{xmlrpc} = [
        $c->forward('/search/bypkgid_rs', [ $searchspec, $pkgid ])
        ->get_column('pkgid')->all
    ];
}

sub bypkgid_rpc : XMLRPCPath('bypkgid') {
    my ( $self, $c, $searchspec, $pkgid ) = @_;
    
    $c->stash->{rs} = $c->forward('/search/bypkgid_rs', [ $searchspec, $pkgid ]);
    #$c->forward('/search/format_search', $searchspec);
}

sub byname : Private {
    my ( $self, $c, $searchspec, $name, $sense, $evr ) = @_;
    $c->stash->{xmlrpc} = [
        $c->forward('/search/byname_rs', [ $searchspec, $name, $sense, $evr ])
        ->get_column('pkgid')->all
    ];
}

=head2 search.rpm.byname (SEARCHSPEC, NAME, [SENSE, EVR])

Search package by its NAME. SENSE and EVR are optional version filter where
SENSE is dependency sign (C<E<gt>>, C<=>, ...) and EVR the search version as
either C<VERSION>, C<VERSION-RELEASE> or C<EPOCH:VERSION-RELEASE>.

SEARCHSPEC is a struct with search options.

=cut

sub byname_rpc : XMLRPCPath('byname') {
    my ( $self, $c, $searchspec, $name, $sense, $evr ) = @_;
    $c->stash->{rs} =
        $c->forward('/search/byname_rs', [ $searchspec, $name, $sense, $evr ]);
}

sub bytag : Private {
    my ( $self, $c, $searchspec, $tagname, $value ) = @_;
    
    $c->stash->{xmlrpc} = [
        $c->forward('/search/bytag_rs', [ $searchspec, $tagname, $value ])
        ->get_column('pkgid')->all
    ];
}

sub bytag_rpc : XMLRPCPath('bytag') {
    my ( $self, $c, $searchspec, $tagname, $value ) = @_;
    
    $c->stash->{rs} = $c->forward('/search/bytag_rs', [ $searchspec, $tagname, $value ]);
    #$c->forward('/search/format_search', $searchspec);
}

sub bydep : XMLRPCPath('/search/rpm/bydep') {
    my ( $self, $c, $searchspec, $deptype, $depname, $depsense, $depevr ) = @_;
    $searchspec ||= {};

    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);

    my $deprs = $c->forward(
        '/search/deps_rs', [ 
            $searchspec, $deptype, $depname,
            $depsense, $depevr 
        ],
    )->get_column('pkgid');
    $c->stash->{rs} = $c->model('Base::Rpms')->search(
        {
            pkgid => 
                { IN => $deprs->as_query, },
        },
        {
            order_by => [ 'name', 'evr using >>', 'issrc', 'arch' ],
        }
    );
}

sub byfile : XMLRPCPath('byfile') {
    my ( $self, $c, $searchspec, $file) = @_;
    $searchspec ||= {};
    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);

    my $filers = $c->forward('/search/file_rs', [ $searchspec, $file ])
        ->get_column('pkgid');
    $c->stash->{rs} = $c->model('Base::Rpms')->search(
        {
            pkgid => { IN => $filers->as_query, },
        },
        {
            order_by => [ 'name', 'evr using >>', 'issrc', 'arch' ],
        }
    );
}

sub fuzzy : XMLRPCPath('fuzzy') {
    my ($self, $c, $searchspec, $name) = @_;
    $searchspec ||= {};

    my $deprs = $c->model('Base')->resultset('Deps')->search(
        { deptype => 'P', depname => { '~*' => $name } }
    )->get_column('pkgid');
    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);

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
#                    { pkgid =>
#                        { IN => $deprs->as_query, },
#                    },
                     ]
                },
                $distrs
                    ? { pkgid => { IN => $distrs->get_column('pkgid')->as_query, }, }
                    : (),
            ]     
        },
    );
}

sub quick : XMLRPCPath('quick') {
    my ($self, $c, $searchspec, @keywords) = @_;
    $searchspec ||= {};
    my $tsquery = join(' & ', map { $_ =~ s/ /\\ /g; $_ } @keywords);
    
    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);

    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
            {
                -or => [
#                    { -nest => \[
#                        "to_tsvector('english', description) @@ to_tsquery(?)",
#                        [ plain_text => $tsquery],
#                    ], },
                    {
                    name => { '~*' => [ @keywords ] },
                    },
                ],
            (exists($searchspec->{src})
                ? (issrc => $searchspec->{src} ? 1 : 0)
                : ()),
            ($distrs 
                ? (pkgid => { IN => $distrs->get_column('pkgid')->as_query, },)
                : ()),
        },
    );
}

sub description : XMLRPCPath('description') {
    my ($self, $c, $searchspec, @keywords) = @_;
    $searchspec ||= {};
    my $tsquery = join(' & ', map { $_ =~ s/ /\\ /g; $_ } @keywords);
    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);
    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
        {
            -nest => \[
                    "to_tsvector('english', description) @@ to_tsquery(?)",
                    [ plain_text => $tsquery],
                ],
                (exists($searchspec->{src})
                    ? (issrc => $searchspec->{src} ? 1 : 0)
                    : ()),
                ($distrs 
                    ? (pkgid => { IN => $distrs->get_column('pkgid')->as_query, },)
                    : ()),
        },
        {
            select => [ 
                "ts_rank_cd(to_tsvector('english', description),to_tsquery(?)) as rank",
                'pkgid'
            ],
            bind => [ $tsquery ], 
            order_by => [ 'rank desc', 'name', 'evr using >>', 'issrc' ],
        },
    )->as_subselect_rs;
}

sub sources : XMLRPCPath('sources') {
    my ( $self, $c, $searchspec, $pkgid ) = @_;

    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);
    my $sourcerpm = $c->forward('/rpms/queryformat', [ $pkgid, '%{SOURCERPM}' ]);
    my $nosourcerpm = $sourcerpm;
    $nosourcerpm =~ s/\.src.rpm$/\.nosrc.rpm/;

    $c->stash->{rs} = $c->model('Base::Rpms')->search(
        {
            -and => [
                { pkgid => {
                    IN => $c->model('Base::RpmFile')->search(
                        { filename => [ $sourcerpm, $nosourcerpm ] }
                    )->get_column('pkgid')->as_query
                }, },
                ($distrs 
                    ? ({ pkgid => { IN => $distrs->get_column('pkgid')->as_query, }, },)
                    : ()),
            ],
        }
    );
}

sub binaries : XMLRPCPath('binaries') {
    my ( $self, $c, $searchspec, $pkgid ) = @_;

    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);
    my $sourcerpm = $c->forward('/rpms/queryformat', [ $pkgid,
            '%{NAME}-%{VERSION}-%{RELEASE}.src.rpm' ]);
    my $nosourcerpm = $sourcerpm;
    $nosourcerpm =~ s/\.src.rpm$/\.nosrc.rpm/;

    my $tagrs = $c->model('Base')->resultset('Tags')
        ->search({ tagname => 'sourcerpm', value => [ $sourcerpm, $nosourcerpm ] })
        ->get_column('pkgid');
    $c->stash->{rs} = $c->model('Base::Rpms')->search(
        {
            -and => [
                { issrc => 0 },
                { pkgid =>
                    { IN => $tagrs->as_query, },
                },
                ($distrs 
                    ? ({ pkgid => { IN => $distrs->get_column('pkgid')->as_query, }, })
                    : ()),
            ]
        },
        {
            order_by => [ qw(arch name), 'evr using >>' ],
        },
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
