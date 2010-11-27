package Sophie::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Admin in Admin.');
}

sub create :XMLRPC {
    my ( $self, $c, $distribution, $version, $arch ) = @_;

    my $rs = $c->model('Base')->resultset('Distribution');
    my $rs_d = $rs->find_or_create({ name => $distribution}) or do {
        $c->stash->{xmlrpc} = 'Erreur adding distrib';
        return;
    };

    my $rs_r = $rs_d->Release->find_or_create({ version => $version, }) or do {
        $c->stash->{xmlrpc} = 'Erreur adding release';
        return;
    };

    my $rs_a = $rs_r->Arch->find_or_create({ arch => $arch }) or do {
        $c->stash->{xmlrpc} = 'Erreur adding arch';
        return;
    };

    $c->stash->{xmlrpc} = 'Ok';

    $c->model('Base')->storage->dbh->commit;

}

sub add_media :XMLRPC {
    my ( $self, $c, $distribspec, $mediaspec) = @_;

    my $d = $c->model('Base')->resultset('Distribution')
        ->search(name => $distribspec->{distribution})
        ->search_related('Release', version => $distribspec->{release})
        ->search_related('Arch', arch => $distribspec->{arch})->next;
    if ($d) {
        my $new = my $rs = $c->model('Base')->resultset('Medias')
            ->update_or_create({
                %{ $mediaspec },
                Arch => $d,
            },
            { key => 'label' }
        );
        if ($new) {
            $c->stash->{xmlrpc} = 'OK';
            $c->model('Base')->storage->dbh->commit;
        } else {
            $c->stash->{xmlrpc} = 'Erreur adding media';
        }
    }
}

sub list_path :XMLRPC {
    my ($self, $c, $distribution, $version, $arch, $media) = @_;
    
    if (ref $distribution) {
        ($distribution, $version, $arch, $media) = 
        (
            $distribution->{distribution},
            $distribution->{release},
            $distribution->{arch},
            $version,
        );
    }

    @{ $c->stash->{xmlrpc} } =
    $c->model('Base')->resultset('Distribution')
        ->search($distribution ? (name => $distribution) : ())
        ->search_related('Release', $version ? (version => $version) : ())
        ->search_related('Arch', $arch ? (arch => $arch) : ())
        ->search_related('Medias', $media ? (label => $media) : ())
        ->search_related('MediasPaths')
        ->search_related('Paths')->get_column('path')
        ->all;
}

sub media_path :XMLRPC {
    my ( $self, $c, $distribution, $version, $arch, $label, $path ) = @_;

    if (ref $distribution) {
        ($distribution, $version, $arch, $label, $path) = 
        (
            $distribution->{distribution},
            $distribution->{release},
            $distribution->{arch},
            $version,
            $arch,
        );
    }

    $path =~ s/\/*$//;
    $path =~ s/\/+/\//g;

    my $med = $c->model('Base')->resultset('Distribution')
        ->search(name => $distribution)
        ->search_related('Release', version => $version)
        ->search_related('Arch', arch => $arch)
        ->search_related('Medias', label => $label)->next or return;

    my $rspath = $c->model('Base')->resultset('Paths')
        ->find_or_create({ path => $path }) or do {
    };
    my $new = $c->model('Base')->resultset('MediasPaths')->new({
            Medias => $med,
            Paths =>  $rspath,
        });
    $new->insert;

    $c->model('Base')->storage->dbh->commit;
}

sub media_remove_path :XMLRPC {
    my ( $self, $c, $distribution, $version, $arch, $label, $path ) = @_;

    if (ref $distribution) {
        ($distribution, $version, $arch, $label, $path) = 
        (
            $distribution->{distribution},
            $distribution->{release},
            $distribution->{arch},
            $version,
            $arch,
        );
    }

    $path =~ s/\/*$//;
    $path =~ s/\/+/\//g;

    my $med = $c->model('Base')->resultset('Distribution')
        ->search(name => $distribution)
        ->search_related('Release', version => $version)
        ->search_related('Arch', arch => $arch)
        ->search_related('Medias', label => $label)->next or return;

    my $rspath = $c->model('Base')->resultset('Paths')
        ->find({ path => $path }) or do {
            return;
    };
    my $new = $c->model('Base')->resultset('MediasPaths')->new({
            Medias => $med,
            Paths =>  $rspath,
        });
    $new->delete;

    $c->model('Base')->storage->dbh->commit;
}

sub ls_local : XMLRPC {
    my ($self, $c, $path) = @_;

    $c->stash->{xmlrpc} = [ <$path*> ];
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
