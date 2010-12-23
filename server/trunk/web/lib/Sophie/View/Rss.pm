package Sophie::View::Rss;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View';

=head1 NAME

Sophie::View::Rss - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=cut

sub process {
    my ($self, $c) = @_;
    if ($c->stash->{rss}) {
    $c->res->content_type('application/rss+xml');
    $c->res->headers->expires(time + 3600);
    $c->response->body($c->stash->{rss}->as_string);
    }
    else {
        die '$c->stash->{rss} is empty';
    }
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
