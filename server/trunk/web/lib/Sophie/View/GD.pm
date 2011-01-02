package Sophie::View::GD;
use Moose;
use namespace::autoclean;
use GD::Graph;

extends 'Catalyst::View::GD';

=head1 NAME

Sophie::View::GD - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=cut

sub process {
    my ($self, $c) = @_;

    my $graph = $c->stash->{xmlrpc}{graph};

    my $gdclass = 'GD::Graph::' . $graph->{type};
    eval "require $gdclass;";
    my $gd = $gdclass->new(@{ $graph->{size} || [ 100, 100 ]});

    $gd->set(%{ $graph->{set} || {} });
    $gd->set_legend(@{ $graph->{legend} }) if ($graph->{legend});

    $c->stash->{gd_image} = $gd->plot($graph->{plot});

    $self->SUPER::process($c);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
