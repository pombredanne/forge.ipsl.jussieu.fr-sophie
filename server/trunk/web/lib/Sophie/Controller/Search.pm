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
    my ($self, $c) = @_;

    if ($c->req->param('page')) {
        $c->req->params->{search} = $c->session->{search};
        $c->req->params->{type} = $c->session->{type};
        $c->req->params->{deptype} = $c->session->{deptype};
    } else {
        $c->session->{search} = $c->req->params->{search};
        $c->session->{type} = $c->req->params->{type};
        $c->session->{deptype} = $c->req->params->{deptype};
    }

    my $searchspec = {
        page => $c->req->param('page') || undef,
    };

    for ($c->req->param('type')) {
        /^byname$/ and do {
            $c->stash->{sargs} = [ {}, $c->req->param('search') ];
            $c->forward('byname', [ $searchspec, $c->req->param('search') ||
                    undef ]);
            last;
        };
        /^bydep$/ and do {
            my @args = ($c->req->param('deptype'), grep { $_ }
                split(/\s+/, $c->req->param('search') || '' ));
            $c->stash->{sargs} = [ {}, @args ],
            $c->forward('bydep', [ $searchspec, @args ]);
            last;
        };
        /^byfile$/ and do {
            my @args = ($c->req->param('search') || '');
            $c->stash->{sargs} = [ {}, @args ],
            $c->forward('byfile', [ $searchspec, @args ]);
            last;
        };
    }

}

sub results :Local {
    my ( $self, $c ) = @_;

    if ($c->req->param('page')) {
        $c->req->params->{search} ||= $c->session->{search};
    }

    if ($c->req->param('search')) {
        $c->session->{search} = $c->req->param('search');
        $c->forward('quick', [
                {
                    page => $c->req->param('page') || undef,
                    src => 0,
                } , grep { $_ } split(/\s/, $c->req->param('search')) ]);

    }
}

sub adv_search :Local {
    my ( $self, $c ) = @_;
}

sub distrib_search : Private {
    my ( $self, $c, $searchspec, $asfilter ) = @_;

    # if asfilter is set, return undef if nothing would have been filter
    if (my $rs = $c->forward('/distrib/distrib_rs', [ $searchspec, $asfilter ]))
    {
        return $rs
            ->search_related('MediasPaths')
            ->search_related('Paths')
            ->search_related('Rpmfiles');
        } else {
            return;
        }
}

sub format_search : Private {
    my ( $self, $c, $searchspec ) = @_;
    $searchspec ||= {};

    my $rs = $c->stash->{rs}->search(
        {},
        {
            page => $searchspec->{page} || 1,
            rows => $searchspec->{rows} || 10,
        },
    );

    $c->stash->{rs} = $rs;
    $c->stash->{column} ||= 'pkgid';
    my @results;
    if (ref $c->stash->{column}) {
        while (my $i = $rs->next) {
            push(@results, {
                map { $_ => $i->get_column($_) } @{$c->stash->{column}} 
            });
        }
    } else {
        @results = $rs->get_column($c->stash->{column})->all;
    }
    $c->stash->{xmlrpc} = {};
    if (!$searchspec->{nopager}) {
        my $pager = $c->stash->{rs}->pager;
        $c->stash->{pager} = $pager;
        $c->stash->{xmlrpc} = {
                pages => $pager->last_page,
                current_page => $pager->current_page,
                total_entries => $pager->total_entries,
                entries_per_page => $pager->entries_per_page,
        };
    }
    $c->stash->{xmlrpc}{results} = \@results;
    return $c->stash->{xmlrpc};
}

=head2 search.rpms.bydate (SEARCHSPEC, TIMESTAMP)

Return a list of rpms files added since TIMESTAMP.
TIMESTAMP must the number of second since 1970-01-01 (eq UNIX epoch).

SEARCHSPEC is a struct with following key/value:

=over 4

=item distribution

Limit search to this distribution

=item release

Limit search to this release

=item arch

Limit search to distribution of this arch

=item src

If set to true, limit search to source package, If set to false, limit search to
binary package.

=item name

Limit search to rpm having this name

=item rows

Set maximum of results, the default is 10000.

=back

Each elements of the output is a struct:

=over 4

=item filename

the rpm filename

=item pkgid

the identifier of the package

=item distribution

the distribution containing this package

=item release

the release containing this package

=item arch

the arch containing this package

=item media

the media containing this package

=back

=cut

sub bydate : XMLRPCPath('/search/rpms/bydate') {
    my ( $self, $c, $searchspec, $date ) = @_;
    $searchspec ||= {};

    return $c->stash->{xmlrpc} = [
        map {
            { 
                filename => $_->get_column('filename'),
                pkgid    => $_->get_column('pkgid'), 
                distribution => $_->get_column('name'),
                release => $_->get_column('version'),
                arch => $_->get_column('arch'),
                media => $_->get_column('label'),
            }
        }
        $c->forward('/distrib/distrib_rs', [ $searchspec ])
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles',
            {
                -nest => \[
                    "Rpmfiles.added > '1970-01-01'::date + ?::interval",
                    [ plain_text => "$date seconds" ],   
                ],
                pkgid => {
                    IN => $c->model('Base::Rpms')->search(
                        {
                            (exists($searchspec->{name})
                                ? (name => $searchspec->{name})
                                : ()
                            ),
                            (exists($searchspec->{src})
                                ? (issrc => $searchspec->{src} ? 1 : 0)
                                : ()
                            ),
                        }
                    )->get_column('pkgid')->as_query,
                }
            },
            {
                select => [qw(filename pkgid name version arch label) ],
                rows => $searchspec->{rows} || 10000,
                order_by => [ 'Rpmfiles.added desc' ],
            },
        )->all ];
}

sub bypkgid : XMLRPCPath('/search/rpm/bypkgid') {
    my ( $self, $c, $searchspec, $pkgid ) = @_;
    $searchspec ||= {};

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [ 
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { pkgid => $pkgid },
                $distrs
                    ? { pkgid => { IN => $distrs->get_column('pkgid')->as_query, } }
                    : ()
            ]     
        },
    );

    $c->forward('format_search', $searchspec);
}

=head2 search.rpm.byname (SEARCHSPEC, NAME, [SENSE, EVR])

Search package by its NAME. SENSE and EVR are optional version filter where
SENSE is dependency sign (C<E<gt>>, C<=>, ...) and EVR the search version as
either C<VERSION>, C<VERSION-RELEASE> or C<EPOCH:VERSION-RELEASE>.

SEARCHSPEC is a struct with search options.

=cut

sub byname : XMLRPCPath('/search/rpm/byname') {
    my ( $self, $c, $searchspec, $name, $sense, $evr ) = @_;
    $searchspec ||= {};

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [ 
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { name => $name },
                ( $evr
                    ? { -nest => \[ 
                        "rpmdepmatch(rpmsenseflag('='), evr, rpmsenseflag(?), ?)",
                        [ plain_text => $sense],
                        [ plain_text => $evr ],
                    ] }
                    : ()),
                ($distrs
                    ? { pkgid => { IN => $distrs->get_column('pkgid')->as_query, }, }
                    : ()),
            ]     
        },
        {
                order_by => [ 'name', 'evr using >>', 'issrc' ],
        }
    );
    $c->forward('format_search', $searchspec);

}

sub bytag : XMLRPCPath('/search/rpm/bytag') {
    my ( $self, $c, $searchspec, $tag, $tagvalue ) = @_;
    $searchspec ||= {};

    my $tagrs = $c->model('Base')->resultset('Tags')
        ->search({ tagname => lc($tag), value => $tagvalue})
        ->get_column('pkgid');
    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);
    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
        {
            -and => [ 
                (exists($searchspec->{src})
                    ? { issrc => $searchspec->{src} ? 1 : 0 }
                    : ()),
                { pkgid => 
                    { IN => $tagrs->as_query, },
                },
                $distrs
                    ? { pkgid => { IN => $distrs->get_column('pkgid')->as_query, }, }
                    : (),
            ]     
        },
    );
    $c->forward('format_search', $searchspec);

}

sub deps_rs : Private {
    my ($self, $c, $searchspec, $deptype, $depname, $depsense, $depevr ) = @_;

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    return $c->model('Base::Deps')->search(
        {
            -and => [
            { deptype => $deptype },
            { depname => $depname },
            ($depsense
                ? ({-nest => \[
                    'rpmdepmatch(flags, evr, rpmsenseflag(?), ?)',
                    [ plain_text => $depsense],
                    [ plain_text => $depevr ]
                ]})
            : ()),
            ($distrs 
                ? ({ pkgid => { IN => $distrs->get_column('pkgid')->as_query,
                        },})
                : ()),
            (exists($searchspec->{src})
                ? { pkgid => { IN => $c->model('Base::Rpms')->search(
                            { issrc => $searchspec->{src} ? 1 : 0 }
                        )->get_column('pkgid')->as_query, }, }
                : ()),
            ($searchspec->{pkgid}
                ? { pkgid => $searchspec->{pkgid} }
                : ()),
            ]
        },
        {
            '+select' => [ { rpmsenseflag => 'flags' }, 'depname', ],
            '+as'     => [ qw(sense name) ],

        }
    );
}

sub file_rs : Private {
    my ( $self, $c, $searchspec, $file) = @_;
    my ($dirname, $basename) = $file =~ m:^(.*/)?([^/]+)$:;
    $dirname =~ m:^[/]: or $dirname = undef;
    if (!$dirname) {
        if ($file =~ /(\*|\?)/) {
            $file =~ tr/*?/%_/;
        } else {
            $file = '%' . $file;
        }
    }
    $searchspec ||= {};

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    return $c->model('Base::Files')->search(
        {
            -and => [
                ($dirname
                    ? (dirname => $dirname)
                    : ()),
                { 'dirname || basename' => { LIKE => $file } },
                basename => $basename,
                ($searchspec->{content} ? { has_content => 1 } : ()),
                ($distrs 
                    ? (pkgid => { IN => $distrs->get_column('pkgid')->as_query, },)
                    : ()),
                ($searchspec->{pkgid}
                    ? { pkgid => $searchspec->{pkgid} }
                    : ()),
            ],
        },
        {
            '+select' => [
                'contents is NOT NULL as has_content',
                { rpmfilesmode => 'mode' },
            ],
            '+as' => [ qw(has_content perm), ],
        }
    );
}

sub bydep : XMLRPCPath('/search/rpm/bydep') {
    my ( $self, $c, $searchspec, $deptype, $depname, $depsense, $depevr ) = @_;
    $searchspec ||= {};

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    my $deprs = $c->forward(
        'deps_rs', [ 
            $searchspec, $deptype, $depname,
            $depsense, $depevr 
        ],
    )->get_column('pkgid');
    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
        {
            pkgid => 
                { IN => $deprs->as_query, },
        },
        {
            order_by => [ 'name', 'evr using >>', 'issrc', 'arch' ],
        }
    );
    $c->forward('format_search', $searchspec);
}

sub byfile : XMLRPCPath('/search/rpm/byfile') {
    my ( $self, $c, $searchspec, $file) = @_;
    $searchspec ||= {};
    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    my $filers = $c->forward('file_rs', [ $searchspec, $file ])
        ->get_column('pkgid');
    $c->stash->{rs} = $c->model('Base')->resultset('Rpms')->search(
        {
            pkgid => { IN => $filers->as_query, },
        },
        {
            order_by => [ 'name', 'evr using >>', 'issrc', 'arch' ],
        }
    );
    $c->forward('format_search', $searchspec);
}

sub fuzzy : XMLRPCPath('/search/rpm/fuzzy') {
    my ($self, $c, $searchspec, $name) = @_;
    $searchspec ||= {};

    my $deprs = $c->model('Base')->resultset('Deps')->search(
        { deptype => 'P', depname => { '~*' => $name } }
    )->get_column('pkgid');
    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

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
    
    $c->forward('format_search', $searchspec);
}

sub quick : XMLRPCPath('/search/rpm/quick') {
    my ($self, $c, $searchspec, @keywords) = @_;
    $searchspec ||= {};
    my $tsquery = join(' & ', map { $_ =~ s/ /\\ /g; $_ } @keywords);
    
    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

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
    $c->forward('format_search', $searchspec);
}

sub description : XMLRPCPath('/search/rpm/description') {
    my ($self, $c, $searchspec, @keywords) = @_;
    $searchspec ||= {};
    my $tsquery = join(' & ', map { $_ =~ s/ /\\ /g; $_ } @keywords);
    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);
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
    $c->forward('format_search', $searchspec);
}

sub sources : XMLRPCPath('/search/rpm/sources') {
    my ( $self, $c, $searchspec, $pkgid ) = @_;

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);
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

    $c->forward('format_search', $searchspec);
}

sub binaries : XMLRPCPath('/search/rpm/binaries') {
    my ( $self, $c, $searchspec, $pkgid ) = @_;

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);
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

    $c->forward('format_search', $searchspec);
}

sub file_search : XMLRPCPath('/search/file/byname') {
    my ( $self, $c, $searchspec, $file) = @_;
    $searchspec ||= {};

    $c->stash->{rs} = $c->forward('file_rs', [ $searchspec, $file ]);
    
    my @col = qw(dirname basename md5 size pkgid count);
    $c->stash->{column} = [ @col, qw(has_content perm user group) ];
    
    $c->forward('format_search', $searchspec);
}

sub dep_search : XMLRPCPath('/search/dep/match') {
    my ($self, $c, $searchspec, $deptype, $depname, $depsense, $depevr) = @_;

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);
    $c->stash->{rs} = $c->forward(
        'deps_rs', [ 
            $searchspec, $deptype, $depname,
            $depsense, $depevr 
        ],
    );

    $c->stash->{column} = [ qw(name sense evr flags pkgid) ];
    $c->forward('format_search', $searchspec);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
