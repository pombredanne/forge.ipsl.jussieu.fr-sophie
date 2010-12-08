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

    $c->response->body('Matched Sophie::Controller::Sources in Sources.');
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
                #has_content => 1,
                basename => $filename,
            },
            {
                    order_by => [ 'evr using >>' ],
            }
        )->all ];

}

sub rpm_sources :Path :Args(1) {
    my ($self, $c, $rpm) = @_;

    $c->forward('srcfiles', [ {}, $rpm ]);

}

sub rpm_sources_file :Path :Args(2) {
    my ($self, $c, $rpm, $filename) = @_;

    $c->forward('srcfilesbyfile', [ {}, $rpm, $filename ]);

}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
