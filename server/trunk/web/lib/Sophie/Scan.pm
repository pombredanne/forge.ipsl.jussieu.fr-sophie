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
            -or => [
                updated => [ 
                    undef,
                    \[ " < now() - '24 hours'::interval"],
                ],
                { needupdate => { '>' => 0 }, },
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
        my $meta = "Sophie::Scan::MetaPath::$type"->new($self, $_);
        $meta->run();
    }
}

sub call_plugins_parser {
    my ($self, $rpm, $pkgid, $new) = @_;
    foreach my $plugins (qw'sources desktopfile config docs') {
        $self->call_plugin_parser($plugins, $rpm, $pkgid, $new);
    }
}

sub call_plugin_parser {
    my ($self, $plugins, $rpm, $pkgid, $new) = @_;
    my $mod = ucfirst(lc($plugins));
    eval "require Sophie::Scan::RpmParser::$mod;";
    warn $@ if($@);
    eval {
        my $parser = "Sophie::Scan::RpmParser::$mod"->new($self);
        $parser->run($rpm, $pkgid, $new);
    }
}

1;
