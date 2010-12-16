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
    my %need_pkgid;
    my %need_pool;
    my @unresolved;
    foreach my $dep (@{ $deplist || []}) {
        my ($depname, $sense, $evr) = ref $dep
            ? @$dep
            : split(/\s+/, $dep);
        $sense ||= '';
        $evr ||= '';

        $depname =~ /^rpmlib\(/ and next;
        my $found = 0;
        if ($depname =~ /^\//) {
            my $res = $c->forward('/search/byfile', [ $searchspec, $depname, ]);
            if (@{$res->{results}}) {
                $found = 1;
                foreach (@{$res->{results}}) {
                    $need_pkgid{$_} = 1;
                }
            } 
            if ($pool) {
                $res = $c->forward('/user/folder/byfile', [ $pool, $depname, ]);
                if (@{$res}) {
                    $found = 1;
                    foreach (@{$res}) {
                        $need_pool{$_} = 1;
                    }
                }
            }
        } else {
            my $res = $c->forward('/search/bydep', [ $searchspec, $over,
                    $depname,
                    $sense,
                    $evr ]);
            if (@{$res->{results}}) {
                $found = 1;
                foreach (@{$res->{results}}) {
                    $need_pkgid{$_} = 1;
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

    $c->stash->{xmlrpc} = {
        unresolved => \@unresolved,
        pkg => [ keys %need_pkgid ],
        pool => [ keys %need_pool ],
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


=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
