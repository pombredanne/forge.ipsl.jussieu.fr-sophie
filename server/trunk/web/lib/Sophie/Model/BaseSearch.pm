package Sophie::Model::BaseSearch;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

=head1 NAME

Sophie::Model::BaseSearch - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub c { $_[0]->{c} }

sub distrib {
    my ($self, $search) = @_;

    # Nothing to filter
    return if (!(
        $search->{distribution} ||
        $search->{release} ||
        $search->{arch} ||
        $search->{media} ||
        $search->{media_group}));

    $self->c->model('Base::Distribution')->search(
        {
            $search->{distribution}
                ? (-or => [
                    { 'me.name' => $search->{distribution} },
                    { shortname => $search->{distribution} },
                ],)
                : ()
        },
        {
            select => [ qw(name shortname) ],
        }

    )->search_related('Release',
        {
            $search->{release}
                ? (version => $search->{release})
                : ()
        },
        {
            select => [ qw(version) ],
        }
    )->search_related('Arch',
        {
            $search->{arch}
                ? ('Arch.arch' => $search->{arch})
                : ()
        },
        {
            select => [ qw(arch) ],
        }
    )->search_related('Medias',
        {
            ($search->{media} ? (label => $search->{media}) : ()),
            ($search->{media_group}
                ? (group_label => $search->{media_group})
                : ()),
        },
        {
            select => [ qw(label group_label) ],
        }
    );
}

sub rpmfiles {
    my ($self, $search) = @_;

    my $rs_dist = $self->distrib($search);

    $rs_dist
        ? $rs_dist->search_related('MediasPaths')
          ->search_related('RpmFiles')
        : $self->c->model('Base::RpmFiles')
}

sub best_rpm_filter {
    my ($self, $search) = @_;

    my $rs_dist = $self->distrib($search);
    return exists($search->{src})
        ? ($rs_dist
            ? $rs_dist->search_related('MediasPaths')
              ->search_related('RpmFiles')
              ->search_related('Rpms', { issrc => $search->{src} ? 1 : 0 })
            : $self->c->model('Base::Rpms',  { issrc => $search->{src} ? 1 : 0 }))
        : ($rs_dist
            ? $rs_dist->search_related('MediasPaths')
              ->search_related('RpmFiles')
            : $self->c->model('Base::RpmFile'))
}

sub ACCEPT_CONTEXT {
    my ($self, $c) = @_;

    $self->{c} = $c;
    return $self;
}

__PACKAGE__->meta->make_immutable;

1;
