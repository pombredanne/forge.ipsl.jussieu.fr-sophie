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
        foreach (qw(distribution release arch)) {
            $c->req->params->{$_} = $c->session->{search_dist}{$_};
        }
    } else {
        $c->session->{search} = $c->req->params->{search};
        $c->session->{type} = $c->req->params->{type};
        $c->session->{deptype} = $c->req->params->{deptype};
        foreach (qw(distribution release arch)) {
            $c->session->{search_dist}{$_} = $c->req->params->{$_};
        }
    }

    my $searchspec = { %{ $c->session->{search_dist} } };

    for ($c->req->param('type')) {
        /^fuzzyname$/ and do {
            $c->stash->{sargs} = [ {}, $c->req->param('search') ];
            $c->visit('/search/rpm/fuzzy_rpc', [ $searchspec, $c->req->param('search') ||
                    undef ]);
            last;
        };
        /^byname$/ and do {
            $c->stash->{sargs} = [ {}, $c->req->param('search') ];
            $c->visit('/search/rpm/byname_rpc', [ $searchspec, $c->req->param('search') ||
                    undef ]);
            last;
        };
        /^bydep$/ and do {
            my @args = ($c->req->param('deptype'), grep { $_ }
                split(/\s+/, $c->req->param('search') || '' ));
            $c->stash->{sargs} = [ {}, @args ],
            $c->visit('/search/rpm/bydep_rpc', [ $searchspec, @args ]);
            last;
        };
        /^byfile$/ and do {
            my @args = ($c->req->param('search') || '');
            $c->stash->{sargs} = [ {}, @args ],
            $c->visit('/search/rpm/byfile_rpc', [ $searchspec, @args ]);
            last;
        };
    }
    #$c->forward('/search/rpm/end');
}

sub results :Local {
    my ( $self, $c ) = @_;

    if ($c->req->param('page')) {
        $c->req->params->{search} ||= $c->session->{search};
    }

    if ($c->req->param('search')) {
        $c->session->{search} = $c->req->param('search');
        $c->visit('/search/rpm/quick', [
                {
                    src => 0,
                } , grep { $_ } split(/\s/, $c->req->param('search')) ]);

    }
    $c->forward('/search/rpm/end');
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
            ->search_related('Rpmfile');
        } else {
            return;
        }
}

sub byname_rs : Private {
    my ( $self, $c, $searchspec, $name, $sense, $evr ) = @_;
    $searchspec ||= {};

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    return $c->model('Base::Rpms')->search(
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
}

sub bytag_rs : Private {
    my ( $self, $c, $searchspec, $tag, $tagvalue ) = @_;
    $searchspec ||= {};

    my $tagrs = $c->model('Base')->resultset('Tags')
        ->search({ tagname => lc($tag), value => $tagvalue})
        ->get_column('pkgid');
    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);
    return $c->model('Base')->resultset('Rpms')->search(
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
}

sub bypkgid_rs : Private {
    my ( $self, $c, $searchspec, $pkgid ) = @_;
    $searchspec ||= {};

    my $distrs = $c->forward('distrib_search', [ $searchspec, 1 ]);

    return $c->model('Base::Rpms')->search(
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
}

sub deps_rs : Private {
    my ($self, $c, $searchspec, $deptype, $depname, $depsense, $depevr ) = @_;

        my $rs = $c->model('Base::Deps')->search(
        {
            -and => [
            { deptype => $deptype },
            { depname => $depname },
            ($depsense
                ? (\[
                    'rpmdepmatch(flags, me.evr, rpmsenseflag(?), ?)',
                    [ plain_text => $depsense],
                    [ plain_text => $depevr ]
                ])
            : ()),
            ($searchspec->{pkgid}
                ? { 'pkgid' => $searchspec->{pkgid} }
                : ()),
            ]
        },
        {
            '+select' => [ { rpmsenseflag => 'flags' }, 'depname',
                'me.evr' ],
            '+as'     => [ qw(sense name evr) ],

        }
    );
    if (exists($searchspec->{src})) {
        $rs = $rs->search_related('Rpms',
            { issrc => $searchspec->{src} ? 1 : 0 }
        )
    }
    return $c->model('BaseSearch')->apply_rpm_filter($rs, $searchspec);
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

    my $rs = $c->model('Base::Files')->search(
        {
            -and => [
                ($dirname
                    ? (dirname => $dirname)
                    : ()),
                { 'dirname || basename' => { LIKE => $file } },
                basename => $basename,
                ($searchspec->{content} ? { has_content => 1 } : ()),
                ($searchspec->{pkgid}
                    ? { 'pkgid' => { IN => $searchspec->{pkgid} } }
                    : ()),
            ],
        },
        {
            '+select' => [
                'contents is NOT NULL as has_content',
                { rpmfilesmode => 'mode' },
            ],
            '+as' => [ qw(has_content perm), ]
        }
    );
    if (exists($searchspec->{src})) {
        $rs = $rs->search_related('Rpms',
            { issrc => $searchspec->{src} ? 1 : 0 }
        )
    }
    return $c->model('BaseSearch')->apply_rpm_filter($rs, $searchspec);
}

sub end : Private {
    my ($self, $c, $searchspec) = @_;

    if ($c->action =~ m:search/[^/]+/.:) {
        my $rs = $c->stash->{rs}->search(
            {},
            {
                page => $searchspec->{page} || 
                     $c->req->param('page') || 1,
                rows => $searchspec->{rows} || 
                     $c->req->param('rows') || 10,
            },
        );

        $c->stash->{rs} = $rs;
        my @results = map { { $_->get_columns } } $rs->all;

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
    } else {
        $c->forward('/end');
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
