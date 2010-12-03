package Sophie::Model::Help::POD;
use Moose;
use namespace::autoclean;
use Pod::Find;
use Pod::POM;
use Pod::POM::View::HTML;

extends 'Catalyst::Model';

=head1 NAME

Sophie::Model::Help::XMLRPC - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub pom {
    my ($self) = @_;
    return values %{ $self->{pom} }
}

sub xmlrpc_functions {
    my ($self) = @_;
    my @pod;
    foreach my $pom ($self->pom) {
        foreach my $head1 ($pom->content) {
            foreach my $item ($head1->content) {
                my $title = $item->title or next;
                $title =~ s/[^\w\._].*$//;
                if ($self->{xmlrpc_methods}->{$title}) {
                     push(@pod, $item);
                }
            }
        }
    }
    my $ppvh = Pod::POM::View::HTML->new;
    return join("\n\n", map { $_->present($ppvh) } @pod);
}

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;

    $self->{xmlrpc_methods} = $c->server->xmlrpc->list_methods;

    foreach my $controller ($c->controllers) {
        my $pod = Pod::Find::pod_where({ -verbose => 0, -inc => 1 },
            "Sophie::Controller::$controller");

        my $parser = Pod::POM->new();
        my $pom = $parser->parse($pod);
        $self->{pom}{$controller} = $pom;

    }

    return $self;
}

__PACKAGE__->meta->make_immutable;

1;
