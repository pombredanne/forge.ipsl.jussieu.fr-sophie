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

sub rpm :Path('/rpm') :Args {
    my ($self, $c, $dist, $rpm, @uargs) = @_;
    
    my @args = split(',', $dist, 3);
    if (@args == 2) {
        unshift(@args, '');
    }
    $c->forward('/distrib/exists', [ { distribution => $args[0], release =>
            $args[1], arch => $args[2] } ]) or $c->go('/404/index');
    $c->res->redirect($c->uri_for('/distrib', @args, 'rpms', $rpm, @uargs));
}

sub srpm :Path('/srpm') :Args {
    my ($self, $c, $dist, $rpm, @uargs) = @_;
    
    my @args = split(',', $dist, 3);
    if (@args == 2) {
        unshift(@args, '');
    }
    $c->forward('/distrib/exists', [ { distribution => $args[0], release =>
            $args[1], arch => $args[2] } ]) or $c->go('/404/index');
    $c->res->redirect($c->uri_for('/distrib', @args, 'srpms', $rpm, @uargs));
}

# /distrib/foo,bar,baz/RPM
sub distrib :Private {
    my ($self, $c, $distrib, $rpm) = @_;

    my @args = split(',', $distrib);
    if (@args == 2) {
        unshift(@args, '');
    }
    $c->forward('/distrib/exists', [ { distribution => $args[0], release =>
            $args[1], arch => $args[2] } ]) or $c->go('/404/index');
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
