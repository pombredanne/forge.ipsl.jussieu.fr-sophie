package Sophie::Controller::Search::File;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Search::File - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Search::File in Search::File.');
}

sub byname : Private {
    my ( $self, $c, $searchspec, $file) = @_;
    $searchspec ||= {};

    my @col = qw(dirname basename md5 size pkgid count);
    $c->stash->{column} = [ @col, qw(has_content perm user group) ];

    $c->stash->{xmlrpc} = [
       map { { $_->get_columns } }
       $c->forward('/search/file_rs', [ $searchspec, $file ])->all
    ];
}

sub byname_rpc : XMLRPCPath('byname') {
    my ( $self, $c, $searchspec, $file) = @_;
    $searchspec ||= {};

    $c->stash->{rs} = $c->forward('/search/file_rs', [ $searchspec, $file ]);
    
    my @col = qw(dirname basename md5 size pkgid count);
    $c->stash->{column} = [ @col, qw(has_content perm user group) ];
    
}


=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
