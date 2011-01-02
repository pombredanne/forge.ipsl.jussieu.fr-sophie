package Sophie::Controller::Distrib;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Distrib - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 distrib.list( [ DISTRIBUTION [, RELEASE [, ARCH ]]]

List content of distrib according arguments given. IE list available
C<distribution> if no argument is given, list C<release> if C<DISTRIBUTION> is
given, list C<arch> if both C<DISTRIBUTION> and C<RELEASE> are given. Etc... Up
to give C<MEDIA> if C<ARCH> is specified.

Results are given as C<ARRAY>.

=cut

sub list :XMLRPC {
    my ( $self, $c, $distrib, $release, $arch ) = @_;

    my $distribution;
    if (ref $distrib) {
        ($distribution, $release, $arch) = (
            $distrib->{distribution},
            $distrib->{release},
            $distrib->{arch},
        );
    } else {
        $distribution = $distrib;
    }

    my $rs = $c->model('Base')->resultset('Distribution');
    if (!$distribution) {
        return $c->stash->{xmlrpc} = [ map { $_->name }
            $rs->search(undef, { order_by => ['name'] })->all ];
    }
    $rs = $rs->search({
            -or => [
                { name      => $distribution },
                { shortname => $distribution },
            ],
        })->search_related('Release');
    if (!$release) {
        return $c->stash->{xmlrpc} = [ map { $_->version }
            $rs->search(undef, { order_by => ['version'] })->all ];
    }
    $rs = $rs->search(version => $release)->search_related('Arch');
    if (!$arch) {
        return $c->stash->{xmlrpc} = [ map { $_->arch } 
            $rs->search(undef, { order_by => ['arch'] })->all ];
    }
    $rs = $rs->search(arch => $arch)->search_related('Medias');
    return $c->stash->{xmlrpc} = [ map { $_->label }
        $rs->search(undef, { order_by => ['label'] })->all ];
}

sub struct :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (!ref $distribution) {
        $distribution = {
            distribution => $distribution,
            release => $release,
            arch => $arch,
        }
    }

    my $rs = $c->forward('distrib_rs', [ $distribution ])
        ->search({}, { order_by => 'label' });
    $c->stash->{xmlrpc} = [ map { 
        { 
            label => $_->label,
            group_label => $_->group_label,
        } 
    } $rs->all ];
}

sub distrib_rs : Private {
    my ( $self, $c, $distrib, $asfilter ) = @_;
    if ($asfilter && !(
            $distrib->{distribution} ||
            $distrib->{release} ||
            $distrib->{arch} ||
            $distrib->{media} ||
            $distrib->{media_group})) {
        return;
    }

    return $c->model('Base')->resultset('Distribution')
        ->search(
            {
                $distrib->{distribution}
                    ? (-or => [
                            { name =>      $distrib->{distribution} },
                            { shortname => $distrib->{distribution} },
                        ],
                    )
                    : ()
            },
            {
                select => [ qw(name shortname) ],
            }
        )->search_related('Release',
            {
                $distrib->{release}
                    ? (version => $distrib->{release})
                    : ()
            },
            {
                select => [ qw(version) ],
            }
        )->search_related('Arch',
            {
                $distrib->{arch}
                    ? (arch => $distrib->{arch})
                    : ()
            },
            {
                select => [ qw(arch) ],
            }
        )->search_related('Medias',
            {
                ($distrib->{media} ? (label => $distrib->{media}) : ()),
                ($distrib->{media_group}
                    ? (group_label => $distrib->{media_group})
                    : ()),
            },
            {
                select => [ qw(label group_label) ],
            }
        );
}

=head2 distrib.exists( DISTRIB )

Return true or false if disteibution C<DISTRIB> exists.

C<DISTRIB> is a structure with following key/value:

=over 4

=item distribution

The distribution name

=item release

The release name

=item arch

The arch name

=back

This function is usefull to check if a search have chance to suceed, eg if the
user is not searching a rpm on a not existing ditribution.

=cut

sub exists : XMLRPC {
    my ( $self, $c, $d ) = @_;

    my $rs = $c->forward('distrib_rs', [ $d ]);

    if ($rs->search({}, { rows => 1 })->next) {
        $c->stash->{xmlrpc} = 1;
    } else {
        $c->stash->{xmlrpc} = 0;
    }
}

=head2 index

=cut

=head2 Url: /distrib

Return the list of currently stored distributions.

=cut

sub index :Path :Chained :Args(0)  {
    my ( $self, $c ) = @_;

    $c->stash->{metarevisite} = 60;
    $c->stash->{metatitle} = 'Available Distribution';
    push(@{$c->stash->{keywords}}, 'Rpm Distribution');
    $c->forward('list');
}

=head2 release

=cut

=head2 Url: /distrib/<DISTRIBUTION>

Return the list of available release for given C<DISTRIBUTION>.

=cut

sub list_release :Path :Args(1) {
    my ( $self, $c, $distribution ) = @_;
    $c->stash->{dist}{distribution} = $distribution;
    if (!$c->forward('exists', [ $c->stash->{dist} ])) {
        $c->go('/404/index');
    }
    $c->stash->{metarevisite} = 60;
    $c->stash->{metatitle} = 'Available release for ' . $distribution;
    push(@{$c->stash->{keywords}}, $distribution);
    $c->forward('list', [ $c->stash->{dist} ] );
}

=head2 Url: /distrib/<DISTRIBUTION>/<RELEASE>

Return the list of available architecture for given C<DISTRIBUTION>,
C<RELEASE>.

=cut

sub list_arch :Path :Args(2) {
    my ( $self, $c, $distribution, $release ) = @_;

    # Compatability with Sophie1
    if ($distribution =~ /^([^,]+,)?[^,]+,[^,]+$/) {
        $c->go('/compat/distrib', [ $distribution, $release ]);
    }

    $c->stash->{dist}{distribution} = $distribution;
    $c->stash->{dist}{release} = $release;
    if (!$c->forward('exists', [ $c->stash->{dist} ])) {
        $c->go('/404/index');
    }
    $c->stash->{metarevisite} = 60;
    $c->stash->{metatitle} =
        'Available architecture for ' . $distribution . ' / ' . $release;
    push(@{$c->stash->{keywords}}, $distribution, $release);
    $c->forward('list', [ $c->stash->{dist} ] );
}


sub distrib_view :PathPrefix :Chained :CaptureArgs(3) {
    my ( $self, $c, $distribution, $release, $arch ) = @_;
    $c->stash->{dist}{distribution} = $distribution;
    $c->stash->{dist}{release} = $release;
    $c->stash->{dist}{arch} = $arch;
    if (!$c->forward('exists', [ $c->stash->{dist} ])) {
        $c->go('/404/index');
    }
    $c->stash->{metarevisite} = 60;
    $c->stash->{metatitle} =
        'Available medias for ' . $distribution . ' / ' . $release . ' / ' . $arch;
    push(@{$c->stash->{keywords}}, $distribution, $release, $arch);
    $c->stash->{distrib} = $c->stash->{dist};
}

=head2 Url: /distrib/<DISTRIBUTION>/<RELEASE>/<ARCH>

Return the list of available medias for given C<DISTRIBUTION>,
C<RELEASE>, C<ARCH>.

=cut

sub distrib :Chained('distrib_view') PathPart('') :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('list', [ $c->stash->{dist} ]);
}

# Url: /distrib/<DISTRIBUTION>/<RELEASE>/<ARCH>/media

sub media :Chained('/distrib/distrib_view') PathPart('media') :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('struct', [ $c->stash->{dist} ]);
}

=head2 distrib.anyrpms( DISTRIB )

Return a list of packages available for C<DISTRIB>.

C<DISTRIB> is a struct with following keys/values:

=over 4

=item distribution

The distribution name

=item release

The release name

=item arch

The arch name

=back

=cut

sub anyrpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (!ref $distribution) {
        $distribution = {
            distribution => $distribution,
            release => $release,
            arch => $arch,
        }
    }

    $c->stash->{rpm} = [ map {
        {
        pkgid => $_->pkgid,
        filename => $_->filename,
        }
        } $c->forward('/search/rpms/rpms_rs', [ $distribution ])
        ->search(
            {
                $c->req->param('fl')
                    ? ( filename => { ILIKE => $c->req->param('fl') . '%' } )
                    : (),
            }, { order_by => [ qw(filename) ] })
        ->all ];

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

=head2 distrib.rpms( DISTRIB )

Return a list of binary packages available for C<DISTRIB>.

C<DISTRIB> is a struct with following keys/values:

=over 4

=item distribution

The distribution name

=item release

The release name

=item arch

The arch name

=back

=cut

sub rpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (!ref $distribution) {
        $distribution = {
            distribution => $distribution,
            release => $release,
            arch => $arch,
        }
    }

    $distribution->{src} = 0;

    $c->stash->{rpm} = [ map {
        {
        pkgid => $_->pkgid,
        filename => $_->filename,
        }
        } $c->forward('/search/rpms/rpms_rs', [ $distribution ])
        ->search(
            {
                $c->req->param('fl')
                    ? ( filename => { ILIKE => $c->req->param('fl') . '%' } )
                    : (),
            }, { order_by => [ qw(filename) ] })
        ->all ];

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

=head2 distrib.srpms( DISTRIB )

Return a list of sources packages available for C<DISTRIB>.

C<DISTRIB> is a struct with following keys/values:

=over 4

=item distribution

The distribution name

=item release

The release name

=item arch

The arch name

=back

=cut

sub srpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (!ref $distribution) {
        $distribution = {
            distribution => $distribution,
            release => $release,
            arch => $arch,
        }
    }

    $distribution->{src} = 1;

    $c->stash->{rpm} = [ map {
        {
        pkgid => $_->pkgid,
        filename => $_->filename,
        }
        } $c->forward('/search/rpms/rpms_rs', [ $distribution ])
        ->search(
            {
                $c->req->param('fl')
                    ? ( filename => { ILIKE => $c->req->param('fl') . '%' } )
                    : (),
            }, { order_by => [ qw(filename) ] })
        ->all ];

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

sub rpms_name :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (!ref $distribution) {
        $distribution = {
            distribution => $distribution,
            release => $release,
            arch => $arch,
        }
    }

    $c->stash->{xmlrpc} = [
        $c->model('Base')->resultset('Rpms')->search(
            { pkgid => {
                IN =>
        $c->forward('distrib_rs', [ $distribution ])
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles')->get_column('pkgid')->as_query
        } },
        { group_by => [ qw(name) ], order_by => [ qw(name) ] }
        )->get_column('name')->all ];
}


=head2 Url: /distrib/<DISTRIBUTION>/<RELEASE>/<ARCH>/rpms

Return the list of available rpms for given C<DISTRIBUTION>,
C<RELEASE>, C<ARCH>.

=cut

sub list_rpms :Chained('distrib_view') PathPart('rpms') Args(0) {
    my ( $self, $c ) = @_;
    if (!$c->forward('exists', [ $c->stash->{dist} ])) {
        $c->go('/404/index');
    }
    $c->stash->{metarevisite} = 60;
    $c->stash->{metatitle} = sprintf(
        'Available Rpms for %s / %s / %s',
        $c->stash->{dist}{distribution},
        $c->stash->{dist}{release},
        $c->stash->{dist}{arch}
    );
    push(@{$c->stash->{keywords}},
        $c->stash->{dist}{distribution},
        $c->stash->{dist}{release},
        $c->stash->{dist}{arch});
    $c->forward('rpms', [ $c->stash->{dist} ]);
}

=head2 Url: /distrib/<DISTRIBUTION>/<RELEASE>/<ARCH>/srpms

Return the list of available sources rpms for given C<DISTRIBUTION>,
C<RELEASE>, C<ARCH>.

=cut

sub list_srpms :Chained('distrib_view') PathPart('srpms') Args(0) {
    my ( $self, $c ) = @_;
    if (!$c->forward('exists', [ $c->stash->{dist} ])) {
        $c->go('/404/index');
    }
    $c->stash->{metarevisite} = 60;
    $c->stash->{metatitle} = sprintf(
        'Available Srpms for %s / %s / %s',
        $c->stash->{dist}{distribution},
        $c->stash->{dist}{release},
        $c->stash->{dist}{arch}
    );
    push(@{$c->stash->{keywords}},
        $c->stash->{dist}{distribution},
        $c->stash->{dist}{release},
        $c->stash->{dist}{arch});
    $c->forward('srpms', [ $c->stash->{dist} ]);
}

=head2 Url: /distrib/<DISTRIBUTION>/<RELEASE>/<ARCH>/srpms/<RPMNAME>

Show the highter version of source rpm named C<RPMNAME> for given
C<DISTRIBUTION>, C<RELEASE>, C<ARCH>.

=cut

sub srpm_by_name :Chained('distrib_view') PathPart('srpms') {
    my ($self, $c, $name, @subpart) = @_;
    $c->stash->{dist}{src} = 1;
    ($c->stash->{pkgid}) = @{ $c->forward('/search/rpm/byname',
        [ $c->stash->{dist}, $name ]) };
    $c->go('/404/index') unless ($c->stash->{pkgid});
    push(@{$c->stash->{keywords}},
        $c->stash->{dist}{distribution},
        $c->stash->{dist}{release},
        $c->stash->{dist}{arch});
    $c->go('/rpms/rpms', [ $c->stash->{pkgid}, @subpart ]);
}

=head2 Url: /distrib/<DISTRIBUTION>/<RELEASE>/<ARCH>/rpms/<RPMNAME>

Show the highter version of binary rpm named C<RPMNAME> for given
C<DISTRIBUTION>, C<RELEASE>, C<ARCH>.

=cut

sub rpm_by_name :Chained('distrib_view') PathPart('rpms') {
    my ($self, $c, $name, @subpart) = @_;
    $c->stash->{dist}{src} = 0;
    ($c->stash->{pkgid}) = @{ $c->forward('/search/rpm/byname',
        [ $c->stash->{dist}, $name ]) };
    $c->go('/404/index') unless ($c->stash->{pkgid});
    push(@{$c->stash->{keywords}},
        $c->stash->{dist}{distribution},
        $c->stash->{dist}{release},
        $c->stash->{dist}{arch});
    $c->go('/rpms/rpms', [ $c->stash->{pkgid}, @subpart ]);
}


=head2 Url: /distrib/<DISTRIBUTION>/<RELEASE>/<ARCH>/by-pkgid/<PKGID>

Show information about rpm having pkgid C<PKGID> for given
C<DISTRIBUTION>, C<RELEASE>, C<ARCH>.

This is likelly the same thing than C</rpm/PKGID> but website will return 404
error if the rpm is not in this distrib

=cut

sub rpm_bypkgid :Chained('distrib_view') PathPart('by-pkgid') {
    my ( $self, $c, $pkgid, @subpart ) = @_;
    if ($pkgid) {
        if (@{ $c->forward('/search/rpm/bypkgid',
            [ $c->stash->{dist}, $pkgid ]) } ) {
            $c->go('/rpms/rpms', [ $pkgid, @subpart ]);
            push(@{$c->stash->{keywords}},
                $c->stash->{dist}{distribution},
                $c->stash->{dist}{release},
                $c->stash->{dist}{arch});
        } else {
            $c->go('/404/index');
        }
    } else {
        $c->forward('anyrpms', [ $c->stash->{dist} ]);
    }
}

sub _media_list_rpms :Chained('distrib_view') PathPart('media') CaptureArgs(1) {
    my ( $self, $c, $media ) = @_;
    $c->stash->{dist}{media} = $media;
    push(@{$c->stash->{keywords}},
        $c->stash->{dist}{distribution},
        $c->stash->{dist}{release},
        $c->stash->{dist}{arch},
        $c->stash->{dist}{media},
    );
}

=head2 Url: /distrib/<DISTRIB>/<RELEASE>/<ARCH>/media/<MEDIA>

Return the list of rpms in media C<MEDIA> for distribution C<DISTRIB>,
C<RELEASE>, C<ARCH>.

The return list is an array of struct:

    [
        {
            filename => 'zvbi-0.2.33-5.fc14.x86_64.rpm',
            pkgid => 'bb9cc5113f0de3e4c7140a1ee8694900'
        },
        {
            filename => 'zvbi-devel-0.2.33-5.fc14.i686.rpm',
            pkgid => '2c3b41c5e1c475dfa31492998eb4de9f'
        }
    ]

=cut

sub media_list_rpms :Chained('_media_list_rpms') PathPart('') :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('anyrpms', [ $c->stash->{dist} ]);
}

=head2 Url: /distrib/<DISTRIB>/<RELEASE>/<ARCH>/media/<MEDIA>/rpms/<NAME>

Show binary rpm named C<NAME> in this distribution/media.

Return C<404> error if such rpm does not exists

=cut

sub media_rpm_byname :Chained('_media_list_rpms') PathPart('rpms') {
    my ( $self, $c, $name, @subpart ) = @_;
    $c->stash->{dist}{src} = 0;
    ($c->stash->{pkgid}) = @{ $c->forward('/search/rpm/byname',
        [ $c->stash->{dist}, $name ]) };
    $c->go('/404/index') unless ($c->stash->{pkgid});
    $c->go('/rpms/rpms', [ $c->stash->{pkgid}, @subpart ]);
}

=head2 Url: /distrib/<DISTRIB>/<RELEASE>/<ARCH>/media/<MEDIA>/srpms/<NAME>

Show source rpm named C<NAME> in this distribution/media.

Return C<404> error if such rpm does not exists

=cut

sub media_srpm_byname :Chained('_media_list_rpms') PathPart('srpms') {
    my ( $self, $c, $name, @subpart ) = @_;
    $c->stash->{dist}{src} = 1;
    ($c->stash->{pkgid}) = @{ $c->forward('/search/rpm/byname',
        [ $c->stash->{dist}, $name ]) };
    $c->go('/404/index') unless ($c->stash->{pkgid});
    $c->go('/rpms/rpms', [ $c->stash->{pkgid}, @subpart ]);
}

=head2 Url: /distrib/<DISTRIB>/<RELEASE>/<ARCH>/media/<MEDIA>/by-pkgid/<PKGID>

Show rpm having C<PKGID> in this distribution/media.

Return C<404> error if such rpm does not exists

=cut

sub media_rpm_bypkgid :Chained('_media_list_rpms') PathPart('by-pkgid') {
    my ( $self, $c, $pkgid, @part ) = @_;
    if ($pkgid) {
        if (@{ $c->forward('/search/rpm/bypkgid', [ $c->stash->{dist}, $pkgid
            ]) } ) {
            $c->stash->{pkgid} = $pkgid;
            $c->go('/rpms/rpms', [ $pkgid, @part ]);
        } else {
            $c->go('/404/index');
        }
    } else {
        $c->forward('anyrpms', [ $c->stash->{dist} ]);
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
