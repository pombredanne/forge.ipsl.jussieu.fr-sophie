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
        [ $c->session->{analyse_dist}, \@deplist, \@folderid ]
    );
}

sub find_requirements : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;

    $pool ||= $id;
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
        [ $distspec, \@deplist, $pool ]);
}

sub find_obsoletes : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;
    $pool ||= $id;
    my @deplist;
    foreach my $dep ($c->model('Base::UsersDeps')->search(
        {
            pid => [ $id ],
            deptype => 'O',
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
    $c->forward('/analysis/solver/find_obsoletes',
        [ $distspec, \@deplist, $pool ]);
}

sub find_conflicts : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;
    $pool ||= $id;
    my @provides;
    foreach my $dep ($c->model('Base::UsersDeps')->search(
        {
            pid => [ $id ],
            deptype => 'C',
        },
        {
            select => [ 'rpmsenseflag("flags")',
                qw(depname flags evr deptype) ],
            as => [ qw'sense depname flags evr deptype' ],
        }
        )->all) {
        $dep->get_column('depname') =~ /^rpmlib\(/ and next;
        push(@provides, [
                $dep->get_column('depname'),
                $dep->get_column('sense'),
                $dep->get_column('evr') ]);
    }
    my @conflicts;
    foreach my $dep ($c->model('Base::UsersDeps')->search(
        {
            pid => [ $id ],
            deptype => 'C',
        },
        {
            select => [ 'rpmsenseflag("flags")',
                qw(depname flags evr deptype) ],
            as => [ qw'sense depname flags evr deptype' ],
        }
        )->all) {
        $dep->get_column('depname') =~ /^rpmlib\(/ and next;
        push(@conflicts, [
                $dep->get_column('depname'),
                $dep->get_column('sense'),
                $dep->get_column('evr') ]);
    }

    $c->forward('/analysis/solver/find_conflicts',
        [ $distspec, \@conflicts, \@provides, $pool ]);
}

sub find_updates : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;
    my $pkg = $c->model('Base::UsersRpms')->find(
        { id => $id }
    );
    $distspec->{src} = $pkg->issrc ? 1 : 0;

    $c->forward('/analysis/solver/find_updates',
        [ $distspec, [ $pkg->name, '<', $pkg->evr ], $pool ]
    );
}

sub is_obsoleted : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;
    
    my $pkg = $c->model('Base::UsersRpms')->find(
        { id => $id }
    );

    $c->forward('/analysis/solver/is_obsoleted',
        [ $distspec, [ [ $pkg->name, '=', $pkg->evr ] ], $pool ]
    );
}

sub is_updated : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;
    my $pkg = $c->model('Base::UsersRpms')->find(
        { id => $id }
    );
    $distspec->{src} = $pkg->issrc ? 1 : 0;

    $c->forward('/analysis/solver/is_updated',
        [ $distspec, [ $pkg->name, '>=', $pkg->evr ], $pool ]
    );
}

sub files_conflicts : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;
    my @files = 
        map { { $_->get_columns } } 
        grep { $_->dirname }
        $c->model('Base::UsersFiles')->search(
            { pid => $id }
    );

    $c->forward('/analysis/solver/files_conflicts',
        [ $distspec, \@files, $pool ]
    );
}

sub parentdir : XMLRPC {
    my ($self, $c, $distspec, $id, $pool) = @_;
    $pool ||= $id;

    my @dir = grep { $_ } $c->model('Base::UsersFiles')->search(
            {
                pid => [ $id ],
            },
            {
                select   => [ qw(dirname) ],
                group_by => [ qw(dirname) ],
                order_by => [ qw(dirname) ],
            }
    )->get_column('dirname')->all;

    $c->forward('/analysis/solver/parentdir', [ $distspec, \@dir, $pool ]);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
