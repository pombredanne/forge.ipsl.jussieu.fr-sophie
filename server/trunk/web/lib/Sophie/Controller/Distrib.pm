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

    my $rs = $c->model('Base')->resultset('Distribution')
        ->search(name => $distribution)
        ->search_related('Release', { version => $release })
        ->search_related('Arch', { arch => $arch })
        ->search_related('Medias')->search({}, { order_by => 'label' });
    $c->stash->{xmlrpc} = [ map { 
        { 
            label => $_->label,
            group_label => $_->group_label,
            key => $_->d_media_key,
        } 
    } $rs->all ];
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

sub distrib :Chained('distrib_view') PathPart('') {
    my ( $self, $c ) = @_;
    $c->forward('list', [ $c->stash->{dist} ]);
    # TODO store properly results
    # No call from json here
}

sub media :Chained('distrib_view') PathPart('media') {
    my ( $self, $c ) = @_;
    $c->forward('struct', [ $c->stash->{dist} ]);
}

sub rpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (ref $distribution) {
        ($distribution, $release, $arch) = (
            $distribution->{distribution},
            $distribution->{release},
            $distribution->{arch},
        );
    }
    
    @{$c->stash->{rpm}} = map {
            { 
              pkgid => $_->pkgid,
              filename => $_->filename,
            }
        }
        $c->model('Base')
        ->resultset('Distribution')->search({ name => $distribution })
        ->search_related('Release', { version => $release })
        ->search_related('Arch',    { arch => $arch })
        ->search_related('Medias')
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles', {
            pkgid => {
                IN => $c->model('Base')->resultset('Rpms')
                ->search({ issrc => 'false' })->get_column('pkgid') ->as_query }
        } )->all;

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

sub srpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;

    if (ref $distribution) {
        ($distribution, $release, $arch) = (
            $distribution->{distribution},
            $distribution->{release},
            $distribution->{arch},
        );
    }

    @{$c->stash->{rpm}} = map {
            { 
              pkgid => $_->pkgid,
              filename => $_->filename,
            }
        }
        $c->model('Base')
        ->resultset('Distribution')->search({ name => $distribution })
        ->search_related('Release', { version => $release })
        ->search_related('Arch',    { arch => $arch })
        ->search_related('Medias')
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles', {
            pkgid => {
                IN => $c->model('Base')->resultset('Rpms')
                ->search({ issrc => 'true' })->get_column('pkgid') ->as_query }
        } )->all;

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

sub list_rpms :Chained('distrib_view') PathPart('rpms') {
    my ( $self, $c ) = @_;
    $c->forward('rpms', $c->stash->{dist});
}

sub list_srpms :Chained('distrib_view') PathPart('srpms') {
    my ( $self, $c ) = @_;
    $c->forward('srpms', $c->stash->{dist});
}

sub srpm_by_name :Chained('distrib_view') PathPart('srpms/by-name') Args(1) {
}
sub rpm_by_name :Chained('distrib_view') PathPart('rpms/by-name') Args(1) {
}
sub rpm_by_pkid :Chained('distrib_view') PathPart('by-pkgid') Args(1) {
}

sub media_rpms : XMLRPC {
    my ( $self, $c, $distribution, $release, $arch, $media ) = @_;
    
    if (ref $distribution) {
        ($distribution, $release, $arch, $media) = (
            $distribution->{distribution},
            $distribution->{release},
            $distribution->{arch},
            $release,
        );
    }
    
    @{$c->stash->{rpm}} = map {
            { 
              pkgid => $_->pkgid,
              filename => $_->filename,
            }
        }
        $c->model('Base')
        ->resultset('Distribution')->search({ name => $distribution })
        ->search_related('Release', { version => $release })
        ->search_related('Arch',    { arch => $arch })
        ->search_related('Medias', { label => $media })
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles')->all;

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}

sub _media_list_rpms :Chained('distrib_view') PathPart('media') CaptureArgs(1) {
    my ( $self, $c, $media ) = @_;
    $c->stash->{media} = $media;
}

sub media_list_rpms :Chained('_media_list_rpms') PathPart('') {
    my ( $self, $c ) = @_;
    $c->forward('media_rpms', [ $c->stash->{dist}, $c->stash->{media} ]);
}

sub media_rpm_byname :Chained('_media_list_rpms') PathPart('rpms/by-name') {
    my ( $self, $c ) = @_;
}
sub media_srpm_byname :Chained('_media_list_rpms') PathPart('srpms/by-name') {
    my ( $self, $c ) = @_;
}
sub media_rpm_bypkgid :Chained('_media_list_rpms') PathPart('by-pkgid') {
    my ( $self, $c, $pkgid ) = @_;
    $c->forward('/rpms/rpms', [ $pkgid ]);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
