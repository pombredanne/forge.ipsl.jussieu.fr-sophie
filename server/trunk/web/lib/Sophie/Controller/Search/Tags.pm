package Sophie::Controller::Search::Tags;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Search::Tags - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub name_regexp_rpc : XMLRPCPath('name_regexp') {
    my ($self, $c, $searchspec, $name) = @_;

    $c->stash->{rs} = $c->forward('/search/rpm/fuzzy_rpc', [ $searchspec, $name ])
        ->search({}, { select => [ qw(name) ], group_by => [ qw(name) ],
                order_by => [ qw(name) ] });
}

sub name_regexp : Private {
    my ($self, $c, $searchspec, $name) = @_;

    $c->stash->{xmlrpc} = [ map { { $_->get_columns } }
    $c->forward('name_regexp_rpc', [ $searchspec, $name ])->all ];
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
