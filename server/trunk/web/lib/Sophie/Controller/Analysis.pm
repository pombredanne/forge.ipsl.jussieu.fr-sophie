package Sophie::Controller::Analysis;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Analysis - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Analysis in Analysis.');
}

sub find_requirements : XMLRPC {
    my ($self, $c, $string) = @_;

    my $id = $c->forward('/user/folder/load_rpm', [ $string ]);

    my @deplist;
    foreach my $dep ($c->model('Base::UsersDeps')->search(
        {
            pid => [ $id ],
            deptype => 'R',
        },
        {
            select => [ 'rpmsenseflag("flags")',
                qw(depname flags evr deptype) ],
            as => [ qw'sense depname flags evr deptype' ],
        }
        )->all) {
        $dep->get_column('depname') =~ /^rpmlib\(/ and next;
        push(@deplist, [
                $dep->get_column('depname'),
                $dep->get_column('sense'),
                $dep->get_column('evr') ]);
    }

    $c->forward('/analysis/solver/find_requirements', [ {}, 'P', \@deplist, $id ]);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
