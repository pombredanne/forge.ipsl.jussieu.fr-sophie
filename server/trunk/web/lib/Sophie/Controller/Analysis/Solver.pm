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

sub find_requirements : XMLRPC {
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


    $c->stash->{xmlrpc} = {
        unresolved => \@unresolved,
        pkg => [ keys %need_pkgid ],
        pool => [ keys %need_pool ],
        bydep => \%bydep,
    };
}

sub parentdir : XMLRPC {
    my ($self, $c, $searchspec, $folder, $pool) = @_;

    my %need_pool;
    my %need_pkgid;
    my %bydir;
    my @notfound;
    foreach my $dir (@{ $folder }) {
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

