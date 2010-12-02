package Sophie::Model::Help::XMLRPC;
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

sub list {
    my ($self) = @_;
    return sort keys %{$self->{method}};
}

sub present {
    my ($self, $section) = @_;
    $self->{method}{$section}->present(Pod::POM::View::HTML->new);
}

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;

    my %method = %{ $c->server->xmlrpc->list_methods };
    foreach my $controller ($c->controllers) {
        my $pod = Pod::Find::pod_where({ -verbose => 0, -inc => 1 },
            "Sophie::Controller::$controller");

        my $parser = Pod::POM->new();
        my $pom = $parser->parse($pod);
        foreach my $item ($pom->content) {
            if ($method{$item->title}) {
                $self->{method}{$item->title} = $item;
            }
        }
    }

    return $self;
}

__PACKAGE__->meta->make_immutable;

1;
