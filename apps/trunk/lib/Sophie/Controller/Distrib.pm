package Sophie::Controller::Distrib;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Distrib - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub list :Path :Args(0) :XMLRPC {
    my ( $self, $c ) = @_;

    $c->model('Base')->connect;
    @{$c->stash->{distribution}} =  map { $_->name }
            $c->model('Base')->resultset('Distribution')->all;
}



sub distribution :XMLRPCLocal :Chained :Path :CaptureArgs(1) {
    my ( $self, $c, $distribution ) = @_;
    $_[1]->log->debug('dd');
    $c->stash->{_distribution} = $c->model('Base')
        ->resultset('Distribution')
        ->search(name => $distribution)
        ->search_related('Release')
        ->all;
}

sub _distribution :PathPart('') :Chained('distribution') :Args(0) {
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
