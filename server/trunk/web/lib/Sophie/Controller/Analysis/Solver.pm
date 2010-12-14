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
    my ($self, $c, $searchspec, $over, $deplist) = @_;

    $searchspec->{nopager} = 1;
    my %need_pkgid;
    my @unresolved;
    foreach my $dep (@{ $deplist || []}) {
        my ($depname, $sense, $evr) = ref $dep
            ? @$dep
            : split(/\s+/, $dep);
        $sense ||= '';
        $evr ||= '';

        $depname =~ /^rpmlib\(/ and next;
        my $res = $c->forward('/search/bydep', [ $searchspec, $over,
                $depname,
                $sense,
                $evr ]);
        if (@{$res->{results}}) {
            foreach (@{$res->{results}}) {
                $need_pkgid{$_} = 1;
            }
        } else {
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
