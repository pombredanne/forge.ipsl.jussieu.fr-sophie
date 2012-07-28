package Sophie::Controller::Analysis::Solver;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Analysis::Solver - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Analysis::Solver in Analysis::Solver.');
}

sub solve_dependencies : Private {
    my ($self, $c, $searchspec, $over, $deplist, $pool) = @_;

    $searchspec->{nopager} = 1;
    $searchspec->{rows} = 10;
    my %need_pkgid;
    my %need_pool;
    my %bydep;
    my @unresolved;
    foreach my $dep (@{ $deplist || []}) {
        my ($depname, $sense, $evr) = ref $dep
            ? @$dep
            : split(/\s+/, $dep);
        $sense ||= '';
        $evr ||= '';

        $depname =~ /^rpmlib\(/ and next;
        my $depdisplay = $depname . ($sense ? " $sense $evr" : '');
        $bydep{$depdisplay} and next; # same already searched
        $bydep{$depdisplay} = {};
        my $found = 0;
        if ($depname =~ /^\//) {
            my $res = $c->forward('/search/rpm/byfile', [ $searchspec, $depname, ]);
            if (@{$res}) {
                $found = 1;
                foreach (@{$res}) {
                    $need_pkgid{$_} = 1;
                    $bydep{$depdisplay}{pkg}{$_} = 1;
                }
            } 
            if ($pool) {
                $res = $c->forward('/user/folder/byfile', [ $pool, $depname, ]);
                if (@{$res}) {
                    $found = 1;
                    foreach (@{$res}) {
                        $need_pool{$_} = 1;
                        $bydep{$depdisplay}{pool}{$_} = 1;

                    }
                }
            }
        } else {
            my $res = $c->forward('/search/rpm/bydep', [ $searchspec, $over,
                    $depname,
                    $sense,
                    $evr ]);
            if (@{$res}) {
                $found = 1;
                foreach (@{$res}) {
                    $need_pkgid{$_} = 1;
                    $bydep{$depdisplay}{pkg}{$_} = 1;
                }
            } 
            if ($pool) {
                $res = $c->forward('/user/folder/bydep', [ $pool, $over,
                        $depname,
                        $sense,
                        $evr ]
                );
                if (@{$res}) {
                    $found = 1;
                    foreach (@{$res}) {
                        $need_pool{$_} = 1;
                        $bydep{$depdisplay}{pool}{$_} = 1;
                    }
                }
            }
        }
        if (!$found) {
            push(@unresolved,
                $depname . (
                    $sense
                    ? sprintf(' %s %s', $sense, $evr)
                    : ''
                )
            );
        }
    }

    foreach my $d (keys %bydep) {
        foreach my $t (keys %{ $bydep{$d} || {} }) {
            $bydep{$d}{$t} = [ keys %{ $bydep{$d}{$t} } ];
        }
    }


    return $c->stash->{xmlrpc} = {
        unresolved => \@unresolved,
        pkg => [ keys %need_pkgid ],
        pool => [ keys %need_pool ],
        bydep => \%bydep,
    };
}

sub solve_name : Private {
    my ($self, $c, $searchspec, $deplist, $pool) = @_;
    my %need_pkgid;
    my %need_pool;
    my %bydep;
    my @unresolved;
    foreach my $dep (@{$deplist || []}) {
        my ($depname, $sense, $evr) = ref $dep
            ? @$dep
            : split(/\s+/, $dep);
        $sense ||= '';
        $evr ||= '';
        my $depdisplay = $depname . ($sense ? " $sense $evr" : '');
        my $found = 0;

        my $res = $c->forward('/search/rpm/byname', [ $searchspec, $depname,
                $sense, $evr ]);
        foreach (@{ $res }) {
            $found = 1;
            $need_pkgid{$_} = 1;
            $bydep{$depdisplay}{pkg}{$_} = 1;
        }

        if (!$found) {
            push(@unresolved, $depdisplay);
        }
    }
    foreach my $d (keys %bydep) {
        foreach my $t (keys %{ $bydep{$d} || {} }) {
            $bydep{$d}{$t} = [ keys %{ $bydep{$d}{$t} } ];
        }
    }
    $c->stash->{xmlrpc} = {
        unresolved => \@unresolved,
        pkg => [ keys %need_pkgid ],
        pool => [ keys %need_pool ],
        bydep => \%bydep,
    }
}

sub find_requirements : Private {
    my ($self, $c, $searchspec, $deplist, $pool) = @_;
    $c->forward('solve_dependencies', [ $searchspec, 'P', $deplist, $pool ]);
}

sub find_conflicts : Private {
    my ($self, $c, $searchspec, $conflicts, $provides, $pool) = @_;
    my $resp = $c->forward('solve_dependencies', [ $searchspec, 'P', $conflicts, $pool ]);
    my $resc = $c->forward('solve_dependencies', [ $searchspec, 'C', $provides,  $pool ]);
    $c->stash->{xmlrpc} = {
        pkg => [ @{ $resp->{pkg} }, @{ $resc->{pkg} } ],
        pool => [ @{ $resp->{pool} }, @{ $resc->{pool} } ],
    }
}

sub is_obsoleted : Private {
    my ($self, $c, $searchspec, $deplist, $pool) = @_;
    $c->forward('solve_dependencies', [ $searchspec, 'O', $deplist, $pool ]);
}

sub is_updated : Private {
    my ($self, $c, $searchspec, $deplist, $pool) = @_;
    $c->forward('solve_name', [ $searchspec, [ $deplist ] ], $pool);
}

sub find_obsoletes : Private {
    my ($self, $c, $searchspec, $deplist, $pool) = @_;
    $c->forward('solve_name', [ $searchspec,  $deplist ], $pool);
}

sub files_conflicts : Private {
    my ($self, $c, $searchspec, $files, $pool) = @_;

    my %fc;
    my %pkgid;
    foreach my $file (@{ $files || []}) {
        my $res = $c->forward('/search/file/byname',
            [ $searchspec,  $file->{dirname} . $file->{basename} ]);
        foreach (@{ $res }) {
            if (($_->{md5} || '') eq ($file->{md5} || '')) {
                next;
            }
            push(@{ $fc{$file->{dirname} . $file->{basename}}}, $_->{pkgid});
            $pkgid{$_->{pkgid}} = 1;
        }
    }
    $c->stash->{xmlrpc} = {
        pkg => [ keys %pkgid ],
        byfile => \%fc,
    }
}

sub parentdir : Private {
    my ($self, $c, $searchspec, $folder, $pool) = @_;

    my %need_pool;
    my %need_pkgid;
    my %bydir;
    my @notfound;
    foreach my $dir (grep { $_ } @{ $folder }) {
        $dir =~ s:/$::;
        my $found = 0;
        my $res = $c->forward('/search/rpm/byfile', [ $searchspec, $dir, ]);
        if (@{$res}) {
            $found = 1;
            foreach (@{$res}) {
                $need_pkgid{$_} = 1;
                $bydir{$dir}{pkg}{$_} = 1;
            }
        } 
        if ($pool) {
            $res = $c->forward('/user/folder/byfile', [ $pool, $dir, ]);
            if (@{$res}) {
                $found = 1;
                foreach (@{$res}) {
                    $need_pool{$_} = 1;
                    $bydir{$dir}{pool}{$_} = 1;

                }
            }
        }
        push(@notfound, $dir) unless($found);
    }
    foreach my $d (keys %bydir) {
        foreach my $t (keys %{ $bydir{$d} || {} }) {
            $bydir{$d}{$t} = [ keys %{ $bydir{$d}{$t} } ];
        }
    }
    return $c->stash->{xmlrpc} = {
        notfound => \@notfound,
        pkg => [ keys %need_pkgid ],
        pool => [ keys %need_pool ],
        bydir => \%bydir,
    };
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

