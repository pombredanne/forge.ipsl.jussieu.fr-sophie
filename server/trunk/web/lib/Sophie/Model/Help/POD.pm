package Sophie::Model::Help::POD;
use Moose;
use namespace::autoclean;
use Pod::Find;
use Pod::POM;
use Pod::POM::View::HTML;
use Pod::POM::View::Text;

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
    my @pom;
    foreach (sort keys %{ $self->{pom} }) {
        push(@pom, $self->{pom}{$_});
    }
    return @pom;
}

sub bot_functions {
    my ($self) = @_;
    my $botpom = $self->{pom}{'Chat::Cmd'};
    foreach my $head1 ($botpom->content) {
        $head1->title eq 'AVAILLABLE FUNCTIONS' or next;
        return map { $_->title } $head1->content;
    }
}

sub bot_help_text {
    my ($self, $cmd) = @_;
    my $botpom = $self->{pom}{'Chat::Cmd'};
    foreach my $head1 ($botpom->content) {
        $head1->title eq 'AVAILLABLE FUNCTIONS' or next;
        foreach ($head1->content) {
            $_->title =~ /^\Q$cmd\E( |$)/ or next;
            my $ppvt = Pod::POM::View::Text->new;
            return $_->present($ppvt);
        }
        last;
    }
    return;
}

sub bot_help_html {
    my ($self, $cmd) = @_;
    my $botpom = $self->{pom}{'Chat::Cmd'};
    foreach my $head1 ($botpom->content) {
        $head1->title eq 'AVAILLABLE FUNCTIONS' or next;
        foreach ($head1->content) {
            $_->title =~ /^\Q$cmd\E( |$)/ or next;
            my $ppvh = Pod::POM::View::HTML->new;
            return $_->present($ppvh);
        }
        last;
    }
    return;
}

sub chat_functions {
    my ($self) = @_;
    my $botpom = $self->{pom}{'Chat::Cmd'};
    foreach my $head1 ($botpom->content) {
        $head1->title eq 'AVAILABLE FUNCTIONS' or next;
        my $ppvh = Pod::POM::View::HTML->new;
        return $head1->present($ppvh);
    }
    return;
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

sub urls_functions {
    my ($self) = @_;
    my @pod;
    foreach my $pom ($self->pom) {
        foreach my $head1 ($pom->content) {
            foreach my $item ($head1->content) {
                my $title = $item->title or next;
                if ($title =~ /^Url:/) {
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
