package Sophie::Scan::MetaPath;

use strict;
use warnings;

sub new {
    my ($class, $base, $meta) = @_;

    bless({ _base => $base, _meta => $meta }, $class);
}

sub base { $_[0]->{_base}->base }

sub meta { $_[0]->{_meta} }

sub clean_obsolete_path {
   my ($self, @currentpaths) = @_;

   foreach ($self->base->resultset('Paths')->search(
           {
               meta_path => $self->meta->d_meta_path_key,
               path => { 'NOT IN' => \@currentpaths },
           })) {
       $_->delete;
   }

   1;
}

sub add_path {
    my ($self, $path, $media) = @_;

    my $rowpath = $self->base->resultset('Paths')->find_or_create(
        { meta_path => $self->meta->d_meta_path_key, path => $path, },
        { key => 'path' }
    );

    my $rowmedia = $self->base->resultset('Medias')->find_or_create(
        { label => $media, d_arch => $self->meta->d_arch, group_label => $media },
        { key => 'label' },
    );

    $self->base->resultset('MediasPaths')->find_or_create(
        {
            d_path => $rowpath->d_path_key,
            d_media => $rowmedia->d_media_key,
        }
    );
}

sub set_updated {
    my ($self) = @_;

    $self->meta->update({ updated => \'now()' });
}

1;
