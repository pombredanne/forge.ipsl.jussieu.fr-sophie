package Sophie::Controller::Chat::Cmd;
use Moose;
use namespace::autoclean;
use Getopt::Long;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Chat::Cmd - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

=head1 BOT COMMAND

=head2 REPLY

=head1 AVAILLABLE FUNCTIONS

=cut

sub _commands {
    my ( $self, $c ) = @_;
    [ grep { m/^[^_]/ } map { $_->name } $self->get_action_methods() ];
}

sub _getopt : Private {
    my ( $self, $c, $options, @args) = @_;

    local @ARGV = @args;

    GetOptions(%{ $options || {} });

    return \@ARGV;
}

=head2 help [cmd]

Return help about command cmd or list availlable command. 

=cut

sub help : XMLRPC {
    my ( $self, $c, $reqspec, $cmd ) = @_;
    if ($cmd) {
        my @message = grep { /\S+/ } split(/\n/,
            $c->model('Help::POD')->bot_help_text($cmd) || 'No help availlable');
        return $c->{stash}->{xmlrpc} = {
            private_reply => 1,
            message => \@message,
        };
    } else {
        return $c->{stash}->{xmlrpc} = {
            private_reply => 1,
            message => [
                'availlable command:',
                join(', ', grep { $_ !~ /^end$/ } @{ $self->_commands }),
            ],
        }
    }
}

=head2 asv

ASV means in french "age, sexe, ville" (age, sex and town).
Return the version of the Chat module version.

=cut

sub asv : XMLRPC {
    my ( $self, $c ) = @_;
    return $c->stash->{xmlrpc} = {
        message => [ 'Sophie: ' . $Sophie::VERSION . ', Chat ' . q$Rev$ ],
    };
}

sub version : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    my @message;
    $reqspec->{src} = 0;

    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
            's'   => sub { $reqspec->{src} = 1 },
        }, @args ]) };

    my $rpmlist = $c->forward('/search/byname', [ $reqspec, $args[0] ]);
    foreach (@{ $rpmlist->{results} }) {
        my $info = $c->forward('/rpms/basicinfo', [ $_ ]);
        push @message, $info->{evr};
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

sub v : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('version', [ @args ]);
}

sub end : Private {
    my ($self, $c ) = @_;
    my $reqspec = $c->req->arguments->[0];
    $reqspec->{max_line} ||= 4;
    my $message =  $c->stash->{xmlrpc};

    my @backup = @{ $message->{message} };
    my $needpaste = 0;

    if (@{ $message->{message} } > ($reqspec->{max_line})) {
        @{ $message->{message} } = 
            # -2 because line 0 and we remove one for paste url
            @backup[0 .. $reqspec->{max_line} -2];
        $needpaste = 1;
    } 

    if ($needpaste) {
        my $id = $c->forward('/chat/paste', [ 'Bot paste', join("\n", @backup) ]);
        push(@{ $message->{message} }, $c->uri_for('/chat', $id));
    }

    $c->stash->{xmlrpc} = $message;

    $c->forward('/end');
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
