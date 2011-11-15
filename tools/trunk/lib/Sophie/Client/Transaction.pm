package Sophie::Client::Transaction;

use strict;
use warnings;

sub new {
    my ($class, $client, $distrib) = @_;

    bless(
        { 
            client => $client,
            distrib => $distrib || {},
        }, 
        $class
    );
}

sub DESTROY {
    my ($self) = @_;
    $self->client->send_request('user.folder.clear');
}

sub client { $_[0]->{client} }
sub distrib { $_[0]->{distrib} }
sub rpmid { sort keys %{ $_[0]->{rpms} || {} } }

sub add_rpm {
    my ($self, $rpm) = @_;

    my $string = `rpm -qp --qf '[%{*:xml}\n]' $rpm`;
    if ($?) {
        warn "$!\n";
        return;
    }
    $string =~ s:<rpmTag name="Changelogname">(.*?)</rpmTag>::sm;
    $string =~ s:<rpmTag name="Changelogtext">(.*?)</rpmTag>::sm;
    $string =~ s:<rpmTag name="Changelogtime">(.*?)</rpmTag>::sm;

    my $res = $self->client->send_request(
        'user.folder.load_rpm',
        RPC::XML::base64->new($string));
    if (ref $res && ! $res->is_fault) {
        $self->{rpms}{$res->value} = $rpm;
        return 1;
    } else {
        warn((ref $res ? $res->string : $res) . "\n");
        return;
    }
}

sub show_pkg {
    my ($self, $pkgid) = @_;

    if ($self->{_cache}{pkg}{$pkgid}) {
        return $self->{_cache}{pkg}{$pkgid};
    } else {
        return
        $self->{_cache}{pkg}{$pkgid} = $self->client->send_request(
            'rpms.basicinfo', $_)
            ->value->{filename};
    }
}

sub check_obsoleted {
    my ($self, $rpmid) = @_;

    my $res = $self->client->send_request(
        'analysis.is_obsoleted',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    if (ref $res && !$res->is_fault) {
        foreach(@{ $res->value->{pkg} || []}) {
            warn sprintf("%s is obsoleted by %s\n",
                $self->{rpms}{$rpmid},
                $self->show_pkg($_)
            );
            push(@{$self->{obsoleted}}, $self->{rpms}{$rpmid});
            $self->{error} = 1;
        }
        foreach($res->value->{pool}) {
        }
    }
}

sub is_updated {
    my ($self, $rpmid) = @_;
    my $res = $self->client->send_request(
        'analysis.is_updated',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    if (ref $res && !$res->is_fault) {
        foreach(@{ $res->value->{pkg} || []}) {
            warn sprintf("%s has lesser version than %s\n",
                $self->{rpms}{$rpmid},
                $self->show_pkg($_)
            );
            $self->{removed}{pkg}{$_} = 1;
            push(@{$self->{obsoleted}}, $self->{rpms}{$rpmid});
            $self->{error} = 1;
        }
        foreach($res->value->{pool}) {
        }
    } else {
        die( ref $res ? $res->string : $res);
    }
}

sub check_conflicts {
    my ($self, $rpmid) = @_;
    my $res = $self->client->send_request(
        'analysis.find_conflicts',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    if (ref $res && !$res->is_fault) {
        foreach(@{ $res->value->{pkg} || []}) {
            $self->{removed}{pkg}{$_} = 1;
        }
        foreach(@{ $res->value->{pool} || []}) {
            $self->{removed}{pool}{$_} = 1;
        }
    }
}

sub find_obsoletes {
    my ($self, $rpmid, %options) = @_;
    my $res = $self->client->send_request(
        'analysis.find_obsoletes',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    if (ref $res && !$res->is_fault) {
        foreach(@{ $res->value->{pkg} || []}) {
            if ($options{verbose}) {
                warn sprintf("%s obsolete %s\n",
                    $self->{rpms}{$rpmid},
                    $self->show_pkg($_)
                );
            }
                
            $self->{removed}{pkg}{$_} = 1;
        }
        foreach(@{ $res->value->{pool} || []}) {
            $self->{removed}{pool}{$_} = 1;
        }
    }
}

sub find_updates {
    my ($self, $rpmid, %options) = @_;
    my $res = $self->client->send_request(
        'analysis.find_updates',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    if (ref $res && !$res->is_fault) {
        foreach(@{ $res->value->{pkg} || []}) {
            $self->{removed}{pkg}{$_} = 1;
            if ($options{verbose}) {
                warn sprintf("%s update %s\n",
                    $self->{rpms}{$rpmid},
                    $self->show_pkg($_)
                );
            }
        }
        foreach(@{ $res->value->{pool} || []}) {
            $self->{removed}{pool}{$_} = 1;
        }
    }
}

sub find_requirements {
    my ($self, $rpmid) = @_;
    my $res = $self->client->send_request(
        'analysis.find_requirements',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    if (ref $res && !$res->is_fault) {
        my $result = $res->value;
        my @unresolved = @{ $result->{unresolved} || []};

        foreach my $dep (keys %{ $result->{bydep} }) {
            my @needs;
            foreach my $pkgid (@{ $result->{bydep}{$dep}{pkg} || []}) {
                if (exists($self->{removed}{pkg}{$pkgid})) {
                    next;
                }
                push(@needs, $pkgid);
            }
            foreach (@{ $result->{bydep}{$dep}{pool} || [] }) {
                if (exists($self->{removed}{pool}{$_})) {
                    next;
                }
                push(@needs, $_);
            }
            if (!@needs) {
                push(@unresolved, $dep) if (!grep { $dep eq $_ } @unresolved);
                $self->{error} = 1;
            }
        }
        if (@unresolved) {
            print $self->{rpms}{$rpmid} . " have missing dependencies:\n";
            print map { "  $_\n" } @unresolved;
        }
        push(@{$self->{unresolved}}, @unresolved);
    }
}

sub unowned_directories {
    my ($self, $rpmid) = @_;

    my $res = $self->client->send_request(
        'analysis.parentdir',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    if (ref $res && !$res->is_fault) {
        my $result = $res->value;
        my @noparent = @{ $result->{notfound} || []};

        foreach my $dir (keys %{ $result->{bydir} }) {
            my @needs;
            foreach my $pkgid (@{ $result->{bydir}{$dir}{pkg} || []}) {
                if (exists($self->{removed}{pkg}{$pkgid})) {
                    next;
                }
                push(@needs, $pkgid);
            }
            foreach (@{ $result->{bydep}{$dir}{pool} || [] }) {
                if (exists($self->{removed}{pool}{$_})) {
                    next;
                }
                push(@needs, $_);
            }
            if (!@needs) {
                push(@noparent, $dir) if (!grep { $dir eq $_ } @noparent);
            }
        }
        if (@noparent) {
            print $self->{rpms}{$rpmid} .
                " have files in non existent directories\n";
            print map { "  $_\n" } sort @noparent;
        }
        push(@{$self->{noparent}}, @noparent);
    }

}

sub files_conflicts {
    my ($self, $rpmid) = @_;

    my $res = $self->client->send_request(
        'analysis.files_conflicts',
        $self->distrib,
        $rpmid,
        $self->rpmid
    );
    my @conflicts;
    if (ref $res && !$res->is_fault) {
        my $result = $res->value;
        foreach my $file (keys %{ $result->{byfile} }) {
            foreach (@{ $result->{byfile}{$file} }) {
                exists($self->{removed}{pkg}{$_}) and next;
                push(@conflicts, $file);
            }
        }
        if (@conflicts) {
            print $self->{rpms}{$rpmid} .
                " have potential file conflicts\n";
            print map { "  $_\n" } sort @conflicts;
        }
    }
}

sub run {
    my ($self, %options) = @_;

    warn "Finding package to remove\n";
    foreach ($self->rpmid) {
        $self->find_updates($_, %options);
        $self->find_obsoletes($_, %options);
    }

    warn "Checking rpm are not obsoleted\n";
    foreach ($self->rpmid) {
        $self->is_updated($_);
        $self->check_obsoleted($_);
    }

    warn "Checking conflicts\n";
    foreach ($self->rpmid) {
        $self->check_conflicts($_);
    }

    warn "Checking requirements\n";
    foreach ($self->rpmid) {
        $self->find_requirements($_);
    }

    warn "Checking files conflicts\n";
    foreach ($self->rpmid) {
        $self->files_conflicts($_);
    }

    warn "Checking parent directory\n";
    foreach ($self->rpmid) {
        $self->unowned_directories($_);
    }


    return $self->{error} ? 0 : 1;
}

sub results {
    my ($self) = @_;

    if (@{$self->{noparent}}) {
        print "This directories are not provided\n";
        print map { "  $_\n" } sort @{$self->{noparent}};
    }

    if (@{$self->{obsoleted}}) {
        print "This packaged will obsoleted by others\n";
        print map { "  $_\n" } @{$self->{obsoleted}};
    }

    if (@{$self->{unresolved}}) {
        print "This dependencies are unresolved:\n";
        print map { "  $_\n" } @{$self->{unresolved}};
    }
    return $self->{error} ? 0 : 1;
}

1;
