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

    if (my $upload = $c->req->upload('file')) {
        if ($upload->size < 5 * 1024 * 1024) { # 5Mo
            $c->forward('/user/folder/load_rpm', [ $upload->slurp ]);
        }
    }
    $c->forward('analyse_folder');
}

sub analyse_folder : Local {
    my ($self, $c) = @_;

    $c->session->{analyse_dist} = {
        distribution => $c->req->param('distribution') || undef,
        release => $c->req->param('release') || undef,
        arch => $c->req->param('arch') || undef,
    };

}

sub required_by :Local {
    my ($self, $c, $id) = @_;
    $id ||= $c->req->param('id');

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

    my @folderid = map { $_->{id} } @{ $c->forward('/user/folder/list') };
    
    $c->stash->{xmlrpc} = $c->forward(
        '/analysis/solver/find_requirements',
        [ $c->session->{analyse_dist},
            'P', \@deplist, \@folderid ]
    );
}

sub find_requirements : XMLRPC {
    my ($self, $c, $distspec, $id, $over, $pool) = @_;

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

    $c->forward('/analysis/solver/find_requirements',
        [ $distspec, 'P', \@deplist, $id, $pool ]);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
