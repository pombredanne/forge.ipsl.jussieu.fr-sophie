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


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Search::File in Search::File.');
}


=head2 byname [ searchspec, Filename ]

Return the list of file named C<Filename> where filename can be:

=over 4

=item the complete path F</usr/bin/perl>

=item the basename F<perl>

=item the basename with the end of the path (bin/perl).

=back

=cut

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

=head2 byname [ searchspec, Md5sum ]

Return the list of file having content checksum equal to C<Md5sum>

=cut

sub bymd5 : Private {
    my ( $self, $c, $searchspec, $md5) = @_;
    $searchspec ||= {};

    my @col = qw(dirname basename md5 size pkgid count);
    $c->stash->{column} = [ @col, qw(has_content perm user group) ];

    $c->stash->{xmlrpc} = [
       map { { $_->get_columns } }
       $c->forward('/search/file_md5_rs', [ $searchspec, $md5 ])->all
    ];
}

sub bymd5_rpc : XMLRPCPath('bymd5') {
    my ( $self, $c, $searchspec, $md5) = @_;
    $searchspec ||= {};

    $c->stash->{rs} = $c->forward('/search/file_md5_rs', [ $searchspec, $md5 ]);
    
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
