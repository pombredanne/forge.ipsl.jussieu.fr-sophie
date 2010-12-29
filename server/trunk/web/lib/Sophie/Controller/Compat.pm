package Sophie::Controller::Compat;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Compat - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub viewrpm :Path('/viewrpm') :Args(0) {
    my ($self, $c) = @_;
    $c->res->redirect($c->uri_for('/rpms'));
}

sub viewrpms :Path('/viewrpm') :Args {
    my ($self, $c, $pkgid, @args) = @_;

    $c->res->redirect($c->uri_for('/rpms', $pkgid, @args));
}

sub rpm :Path('/rpm') :Args(2) {
    my ($self, $c, $dist, $rpm) = @_;
    
    my @args = split(',', $dist);
    if (@args == 2) {
        unshift(@args, '');
    }
    $c->res->redirect($c->uri_for('/distrib', @args, 'rpms', $rpm));
}

sub srpm :Path('/srpm') :Args(2) {
    my ($self, $c, $dist, $rpm) = @_;
    
    my @args = split(',', $dist);
    if (@args == 2) {
        unshift(@args, '');
    }
    $c->res->redirect($c->uri_for('/distrib', @args, 'srpms', $rpm));
}

# /distrib/foo,bar,baz/RPM
sub distrib :Private {
    my ($self, $c, $distrib, $rpm) = @_;

    my @args = split(',', $distrib);
    if (@args == 2) {
        unshift(@args, '');
    }
    $c->res->redirect($c->uri_for('/distrib', @args, 'rpms', $rpm));
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
