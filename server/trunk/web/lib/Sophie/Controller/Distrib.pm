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
    $rs = $rs->search(name => $distribution)->search_related('Release');
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
    my ( $self, $c, $distrib ) = @_;
    return $c->model('Base')->resultset('Distribution')
        ->search(
            {
                $distrib->{distribution}
                    ? (name => $distrib->{distribution})
                    : ()
            },
        )->search_related('Release',
            {
                $distrib->{release}
                    ? (version => $distrib->{release})
                    : ()
            }
        )->search_related('Arch',
            {
                $distrib->{arch}
                    ? (arch => $distrib->{arch})
                    : ()
            }
        )->search_related('Medias',
            {
                ($distrib->{media} ? (label => $distrib->{media}) : ()),
                ($distrib->{media_group}
                    ? (group_label => $distrib->{media_group})
                    : ()),
            },
        );
}


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

sub index :Path :Chained :Args(0)  {
    my ( $self, $c ) = @_;

    $c->forward('list');
}

=head release

=cut

sub list_release :Path :Args(1) {
    my ( $self, $c, $distribution ) = @_;
    $c->stash->{dist}{distribution} = $distribution;
    if (!$c->forward('exists', [ $c->stash->{dist} ])) {
        $c->go('/404/index');
    }
    $c->forward('list', [ $c->stash->{dist} ] );
}

sub list_arch :Path :Args(2) {
    my ( $self, $c, $distribution, $release ) = @_;
    $c->stash->{dist}{distribution} = $distribution;
    $c->stash->{dist}{release} = $release;
    $c->forward('list', [ $c->stash->{dist} ] );
}


sub distrib_view :PathPrefix :Chained :CaptureArgs(3) {
    my ( $self, $c, $distribution, $release, $arch ) = @_;
    $c->stash->{dist}{distribution} = $distribution;
    $c->stash->{dist}{release} = $release;
    $c->stash->{dist}{arch} = $arch;
    $c->stash->{distrib} = $c->stash->{dist};
}

sub distrib :Chained('distrib_view') PathPart('') :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('list', [ $c->stash->{dist} ]);
    # TODO store properly results
    # No call from json here
}

sub media :Chained('/distrib/distrib_view') PathPart('media') :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('struct', [ $c->stash->{dist} ]);
}

sub anyrpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (!ref $distribution) {
        $distribution = {
            distribution => $distribution,
            release => $release,
            arch => $arch,
        }
    }

    @{$c->stash->{rpm}} = map {
            { 
              pkgid => $_->pkgid,
              filename => $_->filename,
            }
        }
        $c->forward('distrib_rs', [ $distribution ])
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles')
        ->all;

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

sub rpms :XMLRPC {
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
        }
        $c->forward('distrib_rs', [ $distribution ])
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles', {
            pkgid => {
                IN => $c->model('Base')->resultset('Rpms')
                ->search({ issrc => 'false' })->get_column('pkgid') ->as_query }
        } )->all ];

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

sub srpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (!ref $distribution) {
        $distribution = {
            distribution => $distribution,
            release => $release,
            arch => $arch,
        }
    }

    @{$c->stash->{rpm}} = map {
            { 
              pkgid => $_->pkgid,
              filename => $_->filename,
            }
        }
        $c->forward('distrib_rs', [ $distribution ])
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles', {
            pkgid => {
                IN => $c->model('Base')->resultset('Rpms')
                ->search({ issrc => 'true' })->get_column('pkgid') ->as_query }
        } )->all;

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

sub list_rpms :Chained('distrib_view') PathPart('rpms') {
    my ( $self, $c ) = @_;
    $c->forward('rpms', $c->stash->{dist});
}

sub list_srpms :Chained('distrib_view') PathPart('srpms') {
    my ( $self, $c ) = @_;
    $c->forward('srpms', $c->stash->{dist});
}

sub srpm_by_name :Chained('distrib_view') PathPart('srpms') Args(1) {
    my ($self, $c, $name) = @_;
    $c->stash->{dist}{src} = 1;
    ($c->stash->{pkgid}) = @{ $c->forward('/search/bytag',
        [ $c->stash->{dist}, 'name', $name ])->{results} };
    $c->go('/404/index') unless ($c->stash->{pkgid});
    $c->go('/rpms/rpms', [ $c->stash->{pkgid} ]);
}

sub rpm_by_name :Chained('distrib_view') PathPart('rpms') Args(1) {
    my ($self, $c, $name) = @_;
    $c->stash->{dist}{src} = 0;
    ($c->stash->{pkgid}) = @{ $c->forward('/search/bytag',
        [ $c->stash->{dist}, 'name', $name ]) };
    $c->go('/404/index') unless ($c->stash->{pkgid});
    $c->go('/rpms/rpms', [ $c->stash->{pkgid} ]);
}

sub rpm_bypkgid :Chained('distrib_view') PathPart('by-pkgid') {
    my ( $self, $c, $pkgid ) = @_;
    if ($pkgid) {
        if (@{ $c->forward('/search/bypkgid', [ $c->stash->{dist}, $pkgid ]) } ) {
            $c->go('/rpms/rpms', [ $pkgid ]);
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
}

sub media_list_rpms :Chained('_media_list_rpms') PathPart('') :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('anyrpms', [ $c->stash->{dist} ]);
}

sub media_rpm_byname :Chained('_media_list_rpms') PathPart('rpms') {
    my ( $self, $c, $name ) = @_;
}
sub media_srpm_byname :Chained('_media_list_rpms') PathPart('srpms') {
    my ( $self, $c, $name ) = @_;
}

sub media_rpm_bypkgid :Chained('_media_list_rpms') PathPart('by-pkgid') {
    my ( $self, $c, $pkgid ) = @_;
    if ($pkgid) {
        if (@{ $c->forward('/search/bypkgid', [ $c->stash->{dist}, $pkgid ]) } ) {
            $c->go('/rpms/rpms', [ $pkgid ]);
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
