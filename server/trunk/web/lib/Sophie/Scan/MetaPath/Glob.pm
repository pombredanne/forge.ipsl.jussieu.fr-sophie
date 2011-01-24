package Sophie::Scan::MetaPath::Glob;

use strict;
use warnings;
use base qw(Sophie::Scan::MetaPath);

sub run {
    my ($self) = @_;

    my @path = grep { -d $_ } glob($self->meta->path);

    $self->base->storage->txn_do(
        sub {
            $self->clean_obsolete_path(@path);

            foreach (@path) {
                $self->add_path($_, $self->meta->data);
            }
            $self->set_updated;
        }
    );
}

1;
