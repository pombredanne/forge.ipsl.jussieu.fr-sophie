package Sophie::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Sophie::Controller::Root - Root Controller for Sophie

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

sub begin : Private {
    my ( $self, $c ) = @_;

    if ($c->req->path =~ m:[^/]+\/$:) {
        my $path = $c->req->path;
        $path =~ s:/*$::;
        $c->res->redirect($c->uri_for("/$path"));
        return;
    }

    if (($c->req->query_keywords || '') =~ /([^\w]|^)json([^\w]|$)/ ||
        exists($c->req->params ->{json})) {
        $c->stash->{current_view} = 'Json';
    }
    if (($c->req->query_keywords || '') =~ /([^\w]|^)ajax([^\w]|$)/ ||
        exists($c->req->params ->{ajax})) {
        $c->stash->{current_view} = 'Ajax';
    }

    if ($c->action =~ m/^admin\//) {
        if (!$c->user_exists) {
            $c->res->redirect($c->uri_for('/login'));
        }
    }
}

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Hello World
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub _end : ActionClass('RenderView') {}

sub  end : Private {
    my ( $self, $c ) = @_;
    if (!$c->req->xmlrpc->method) {
        $c->forward('_end');
    } elsif (!$c->stash->{current_view}) {
    }
    $c->stash->{data} = $c->stash->{xmlrpc};
    $c->model('Base')->storage->dbh->commit;
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
