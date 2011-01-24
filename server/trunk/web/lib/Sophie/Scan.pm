package Sophie::Scan;

use strict;
use warnings;
use Sophie::Base;

sub new {
    my ($class) = @_;

    my $base = Sophie::Base->connect or return;

    bless({ _base => $base }, $class);
}

sub base { $_[0]->{_base} }

sub commit {
    my ($self) = @_;
    #$self->base->storage->dbh->commit;
    1;
}

sub list_unscanned_paths {
    my ($self) = @_;

    return $self->base->resultset('Paths')->search({
            updated => [ undef,
            \[ " < now() - '24 hours'::interval"],
            ],
    })->get_column('d_path_key')->all
}

sub paths_to_keys {
    my ($self, @paths) = @_;

    return $self->base->resultset('Paths')->search({
            path => [ @paths ],
        })->get_column('d_path_key')->all
}

sub list_paths {
    my ($self, $host) = @_;
    return $self->base->resultset('Paths')->search(
        {
            $host ? (host => $host) : (),
        }
    )->get_column('path')->all
}

sub update_meta_paths {
    my ($self) = @_;

    foreach ($self->base->resultset('MetaPaths')->search({
            updated => [ undef,
            \[ " < now() - '24 hours'::interval"],
            ],
        })->all) {
        my $type = ucfirst(lc($_->type));
        eval "require Sophie::Scan::MetaPath::$type";
        if ($@) {
            warn "Cannot load MetaPath $type: $@";
            next;
        }
        warn "$$ Updating Meta $_";
        my $meta = "Sophie::Scan::MetaPath::$type"->new($self, $_);
        $meta->run();
    }
}

1;
