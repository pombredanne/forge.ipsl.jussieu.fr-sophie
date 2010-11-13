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
    my ( $self, $c, $distribution, $release ) = @_;
    $c->session->{toto} = 1; 
    my $rs = $c->model('Base')->resultset('Distribution');
    if (!$distribution) {
        @{$c->stash->{xmlrpc}} = map { $_->name } $rs->all;
        return;
    }
    $rs = $rs->search(name => $distribution)->search_related('Release');
    if (!$release) {
        @{$c->stash->{xmlrpc}} = map { $_->version } $rs->all;
        return;
    }
    $rs = $rs->search(version => $release)->search_related('Arch');
    @{$c->stash->{xmlrpc}} = map { $_->arch } $rs->all;
}

sub struct :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;
    my $rs = $c->model('Base')->resultset('Distribution')
        ->search(name => $distribution)
        ->search_related('Release', { version => $release })
        ->search_related('Arch', { arch => $arch })
        ->search_related('Medias');
    @{$c->stash->{xmlrpc}} = map { 
        { 
            label => $_->label,
            group_label => $_->group_label,
            key => $_->d_media_key,
        } 
    } $rs->all;
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
    $c->forward('list', [ $distribution ]);
}

sub list_arch :Path :Args(2) {
    my ( $self, $c, $distribution, $release ) = @_;
    $c->forward('list', [ $distribution, $release ]);
}


sub distrib_view :PathPrefix :Chained :CaptureArgs(3) {
    my ( $self, $c, $distribution, $release, $arch ) = @_;
    $c->stash->{distrib} = [ $distribution, $release, $arch ];
    warn @{$c->req->args};
}

sub distrib :Chained('distrib_view') PathPart('') {
    my ( $self, $c ) = @_;
    $c->forward('list', $c->stash->{distrib});
    $c->forward('rpms',    $c->stash->{distrib});
    # TODO store properly results
    # No call from json here
}

sub media :Chained('distrib_view') PathPart('media') {
    my ( $self, $c ) = @_;
    $c->forward('struct', $c->stash->{distrib});
}

sub rpms :XMLRPC {
    my ( $self, $c, $distribution, $release, $arch ) = @_;
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

sub media_rpms : XMLRPC {
    my ( $self, $c, $media_key ) = @_;
    @{$c->stash->{rpm}} = map {
            { 
              pkgid => $_->pkgid,
              filename => $_->filename,
            }
        }
        $c->model('Base')
        ->resultset('Medias')->search({ d_media_key => $media_key })
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfiles')->all;

    $c->stash->{xmlrpc} = $c->stash->{rpm};
}


sub list_rpms :Chained('distrib_view') PathPart('rpms') {
    my ( $self, $c ) = @_;
    $c->forward('rpms',    $c->stash->{distrib});
}

sub list_srpms :Chained('distrib_view') PathPart('srpms') {
    my ( $self, $c ) = @_;
    $c->forward('srpms',    $c->stash->{distrib});
}

sub srpm_by_name :Chained('distrib_view') PathPart('srpms/by-name') Args(1) {
}
sub rpm_by_name :Chained('distrib_view') PathPart('rpms/by-name') Args(1) {
}
sub rpm_by_pkid :Chained('distrib_view') PathPart('rpms/by-pkgid') Args(1) {
}

sub _media_list_rpms :Chained('distrib_view') PathPart('media') CaptureArgs(1) {
    my ( $self, $c, $media ) = @_;
    $c->stash->{media} = $media;
}

sub media_list_rpms :Chained('_media_list_rpms') PathPart('') {
    my ( $self, $c ) = @_;
    $c->forward('media_rpms', [ $c->stash->{media} ]);
}
sub media_rpm_byname :Chained('_media_list_rpms') PathPart('rpms/by_name') {
    my ( $self, $c ) = @_;
}
sub media_srpm_byname :Chained('_media_list_rpms') PathPart('srpms/by_name') {
    my ( $self, $c ) = @_;
}
sub media_rpm_bypkgid :Chained('_media_list_rpms') PathPart('rpms/by_pkgid') {
    my ( $self, $c ) = @_;
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
