package Sophie::Controller::Sources;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Sources - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->req->param('search')) {
        $c->stash->{xmlrpc} = [ $c->model('Base::Rpms')
        ->search(
            {
                name => { 'LIKE' => $c->req->param('search') . '%' },
                issrc => 1,
            },
            {
                group_by => [ qw(name) ],
                select => [ qw(name) ],
            }
        )->get_column('name')->all ];
    } else {
        $c->stash->{xmlrpc} = [];
    }
}

sub srcfiles : XMLRPCLocal {
    my ($self, $c, $searchspec, $name) = @_;

    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);
    my $rpmrs = ($distrs
        ? $distrs->search_related('RpmsFile')
        : undef);

    $c->stash->{xmlrpc} = [ 
        map {
         { $_->get_columns }
        }
        
        $c->model('Base::Rpms')
        ->search(
            { 
                name => $name,
                issrc => 1,
                $rpmrs
                    ? (pkgid => { IN => $rpmrs->get_column('pkgid')->as_query },)
                    : (),
            },
            {
                select => [ 'evr' ],
            }
        )->search_related('SrcFiles')->search(
            {
                #has_content => 1,
            },
            {
                    select => [ 'basename', 'evr', 'SrcFiles.pkgid' ],
                    group_by => [ 'basename', 'evr', 'SrcFiles.pkgid' ],
                    order_by => [ 'evr using >>', 'basename' ],
            }
        )->all ];
}

sub srcfilesbyfile : XMLRPCLocal {
    my ($self, $c, $searchspec, $name, $filename) = @_;

    my $distrs = $c->forward('/search/distrib_search', [ $searchspec, 1 ]);
    my $rpmrs = ($distrs
        ? $distrs->search_related('RpmsFile')
        : undef);

    $c->stash->{xmlrpc} = [ 
        map {
         { $_->get_columns }
        }
        
        $c->model('Base::Rpms')
        ->search(
            { 
                name => $name,
                issrc => 1,
                $rpmrs
                    ? (pkgid => { IN => $rpmrs->get_column('pkgid')->as_query },)
                    : (),
            },
            {
                select => [ 'evr' ],
            }
        )->search_related('SrcFiles')->search(
            {
                has_content => 1,
                basename => $filename,
            },
            {
                    '+columns' => [ qw(me.evr) ],
                    order_by => [ 'evr using >>' ],
            }
        )->all ];

}

sub rpm_sources_ :PathPrefix :Chained :CaptureArgs(1) {
    my ($self, $c, $rpm) = @_;
    $c->stash->{rpm} = $rpm;
}

sub rpm_sources :Chained('rpm_sources_') :PathPart('') :Args(0) {
    my ($self, $c, $rpm) = @_;

    $c->forward('srcfiles', [ {}, $c->stash->{rpm} ]);

}

sub rpm_sources_file_ :Chained('rpm_sources_') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $filename) = @_;
    $c->stash->{filename} = $filename;

    $c->stash->{list} = $c->forward('srcfilesbyfile', [ {},
        $c->stash->{rpm}, $c->stash->{filename} ] );
}

sub rpm_sources_file :Chained('rpm_sources_file_') :PathPart('') :Args(0) {
    my ($self, $c ) = @_;

    #$c->forward('srcfilesbyfile', [ {},
    #        $c->stash->{rpm}, $c->stash->{filename} ] );

}

sub rpm_sources_file_pkg_ :Chained('rpm_sources_file_') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $pkgid) = @_;
    $c->stash->{pkgid} = $pkgid;
    $c->stash->{xmlrpc} = { $c->model('Base::SrcFiles')->find(
        {

            pkgid => $c->stash->{pkgid},
            basename => $c->stash->{filename},
        },
        {
            '+columns' => ['contents'],
        }
    )->get_columns };
}

sub rpm_sources_file_pkg :Chained('rpm_sources_file_pkg_') :PathPart('') :Args(0) {
    my ($self, $c) = @_;

}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
