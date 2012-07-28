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

sub apply_rpm_filter {
    my ($self, $rs, $search) = @_;

    # Nothing to filter
    return $rs if (!(
        $search->{distribution} ||
        $search->{release} ||
        $search->{arch} ||
        $search->{media} ||
        $search->{media_group}));

    $rs->search_related('RpmFile')
    ->search_related('MediasPaths')
    ->search_related('Medias',
        {
            ($search->{media} ? (label => $search->{media}) : ()),
            ($search->{media_group}
                ? (group_label => $search->{media_group})
                : ()),
        },
        {
            select => [ qw(label group_label) ],
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

    )->search_related('Release',
        {
            $search->{release}
            ? (version => $search->{release})
            : ()
        },
        {
            select => [ qw(version) ],
        }
    )->search_related('Distribution')->search(
        {
            $search->{distribution}
            ? (-or => [
                    { 'Distribution.name' => $search->{distribution} },
                    { shortname => $search->{distribution} },
                ],)
            : ()
        },
        {
            select => [ qw(name shortname) ],
        }
    );
}

sub ACCEPT_CONTEXT {
    my ($self, $c) = @_;

    $self->{c} = $c;
    return $self;
}

__PACKAGE__->meta->make_immutable;

1;
