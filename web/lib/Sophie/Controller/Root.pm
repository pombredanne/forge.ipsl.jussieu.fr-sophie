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

    if ($c->req->path =~ m:[^/]+\/+$:) {
        my $path = $c->req->path;
        $path =~ s:/*$::;
        $c->res->redirect($c->uri_for("/$path"));
        return;
    }

    if (!$c->stash->{sitepath}) {
        my @path;
        my @reqpath = split('/', $c->req->path);
        foreach (@reqpath) {
            push(@path, $_);
            push(@{ $c->stash->{sitepath} }, { path => $c->uri_for('/', @path),
                    name => $_ || '*' });
        }
    }

    if (($c->req->query_keywords || '') =~ /([^\w]|^)json([^\w]|$)/ ||
        exists($c->req->params ->{json})) {
        $c->stash->{current_view} = 'Json';
    }
    if (($c->req->query_keywords || '') =~ /([^\w]|^)ajax([^\w]|$)/ ||
        exists($c->req->params ->{ajax})) {
        $c->stash->{current_view} = 'Ajax';
    }

    #$c->delete_expired_sessions;
}

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{metarevisite} = 1;
    $c->stash->{xmlrpc} = $c->forward(
        '/search/rpms/bydate',
        [
            {
                src => 1,
                rows => 20,
            },
            1
        ]
    ); 
}

sub robots :Path('/robots.txt') {
    my ($self, $c) = @_;

    $c->serve_static_file($c->path_to('root', 'static', 'robots.txt'));
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->go('/404/index');
}

=head2 end

Attempt to render a view, if needed.

=cut

sub _end : ActionClass('RenderView') {}

sub  end : Private {
    my ( $self, $c ) = @_;
    if (!$c->stash->{current_view}) {
        if (ref($c->stash->{xmlrpc}) eq 'HASH' &&
            $c->stash->{xmlrpc}{graph}) {
            $c->stash->{current_view} = 'GD';
        }
    }
    if (!$c->req->xmlrpc->method) {
        $c->forward('_end');
    }
    $c->stash->{data} = $c->stash->{xmlrpc};
    $c->model('Base')->storage->dbh->rollback;
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
