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

=head2 end

=cut

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
        push(@{ $message->{message} }, 'All results availlable here: ' . $c->uri_for('/chat', $id));
    }

    $c->stash->{xmlrpc} = $message;

    $c->forward('/end');
}

=head1 BOT COMMAND

=head2 REPLY

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

sub _fmt_location : Private {
    my ($self, $c, $pkgid) = @_;

    my @loc;
    foreach (@{ $c->forward('/rpms/location', [ $pkgid ]) }) {
        push @loc, sprintf(
            '%s (%s, %s, %s)',
            $_->{media},
            $_->{dist} || $_->{distribution},
            $_->{release},
            $_->{arch},
        );
    }
    return join(', ', @loc);
}

=head1 AVAILLABLE FUNCTIONS

=cut

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
                join(', ', sort grep { $_ !~ /^end$/ } @{ $self->_commands }),
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

=head2 version [-s] NAME

Show the version of package C<NAME>.

=cut

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
        push @message, $info->{evr} . ' // ' .
            $c->forward('_fmt_location', [ $_ ]);
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

=head2 v

C<v> is an alias for C<version> command.

=cut

sub v : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('version', [ @args ]);
}

=head2 packager [-s] NAME

Show the packager of package C<NAME>.

=cut

sub packager : XMLRPC {
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
        my $info = $c->forward('/rpms/queryformat', [ $_, '%{packager}' ]);
        push @message, $info . ' // ' .
            $c->forward('_fmt_location', [ $_ ]);
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

=head2 p

Is an alias for C<packager> command.

=cut

sub p : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('packager', [ @args ]);
}

=head2 arch [-s] NAME

Show the architecture of package C<NAME>.

=cut 

sub arch : XMLRPC {
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
        my $info = $c->forward('/rpms/queryformat', [ $_, '%{arch}' ]);
        push @message, $info . ' // ' .
            $c->forward('_fmt_location', [ $_ ]);
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

=head2 a

Is an alias to C<arch> command.

=cut 

sub a : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('arch', [ @args ]);
}

=head2 buildtime [-s] NAME

Show the build time of package C<NAME>.

=cut

sub buildtime : XMLRPC {
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
        my $info = $c->forward('/rpms/queryformat', [ $_, '%{buildtime:date}' ]);
        push @message, $info . ' // ' .
            $c->forward('_fmt_location', [ $_ ]);
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

=head2 builddate

Is an alias for C<buildtime> command.

=cut

sub builddate : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('buildtime', [ @args ]);
}

=head2 builddate

Is an alias for C<buildtime> command.

=cut

sub b : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('builddate', [ @args ]);
}

=head2 qf rpmname format

Perform an rpm -q --qf on package named C<rpmname>

=cut

sub qf : XMLRPC {
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
        my $info = $c->forward('/rpms/queryformat', [ $_, $args[1] ]);
        push @message, $info;
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
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
