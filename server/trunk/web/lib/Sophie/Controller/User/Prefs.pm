package Sophie::Controller::User::Prefs;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::User::Prefs - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::User::Prefs in User::Prefs.');
}

sub get_default_distrib :Private {
    my ( $self, $c, $section ) = @_;

    $section ||= 'all';

    return 
        $c->session->{default}{$section}{distrib} ||
        $c->session->{default}{all}{distrib}
}

sub set_default_distrib :Local {
    my ( $self, $c ) = @_;

    my $section = $c->req->param('section') || 'all';

    $c->session->{default}{$section}{distrib} = {
        distribution => $c->req->param('distribution') || undef,
        release => $c->req->param('release') || undef,
        arch => $c->req->param('arch') || undef,
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
