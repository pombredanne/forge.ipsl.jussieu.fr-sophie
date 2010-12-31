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
    
    $c->forward('/chat/update_statistic', [ ($c->action =~ /([^\/]+)$/)[0] ]);

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

    if ($needpaste && !$reqspec->{nopaste}) {
        my $cmd = ($c->action =~ /([^\/]+)$/)[0];
        my (undef, undef, @args) = @{ $c->req->arguments };
        my $title = join(' ', $cmd, @args); 
        my $id = $c->forward('/chat/paste', [ $title, join("\n", @backup) ]);
        if ($id) {
            push(@{ $message->{message} }, 'All results available here: ' . $c->uri_for('/chat', $id));
        }
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
    my ($self, $c, $searchspec, $pkgid) = @_;

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

sub _find_rpm_elsewhere : Private {
    my ($self, $c, $searchspec, $name) = @_;
    if ($searchspec->{distribution}) {
        my $rpmlist = $c->forward('/search/rpm/byname', [ 
                {
                    distribution => $searchspec->{distribution},
                    rows => 1,
                }, $name ]);
        if (@{$rpmlist}) {
            return $c->forward('_fmt_location', [ { 
                        distribution => $searchspec->{distribution}
                    }, $rpmlist->[0] ]);
        }
    }
    my $rpmlist = $c->forward('/search/rpm/byname', [ {}, $name ]);
    my %dist;
    foreach(@$rpmlist) {
        foreach (@{ $c->forward('/rpms/location', [ $_ ]) }) {
            $dist{$_->{dist} || $_->{distribution}} = 1;
        }
    }
    if (keys %dist) {
        return join(', ', sort keys %dist);
    }
    return;
}

=head1 AVAILABLE FUNCTIONS

=cut

=head2 help [cmd]

Return help about command cmd or list available command. 

=cut

sub help : XMLRPC {
    my ( $self, $c, $reqspec, $cmd ) = @_;
    if ($cmd) {
        my @message = grep { /\S+/ } split(/\n/,
            $c->model('Help::POD')->bot_help_text($cmd) || 'No help available');
        return $c->{stash}->{xmlrpc} = {
            private_reply => 1,
            message => \@message,
        };
    } else {
        return $c->{stash}->{xmlrpc} = {
            private_reply => 1,
            message => [
                'available command:',
                join(', ', sort grep { $_ !~ /^end$/ } @{ $self->_commands }),
                'Find more at ' . $c->uri_for('/help/chat'),
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

=head2 q REGEXP

Search rpm name matching C<REGEXP>.

NB: C<.>, C<*>, C<+> have special meaning
and have to be escaped.

=cut

sub q : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $reqspec->{src} = 0;

    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
            's'   => sub { $reqspec->{src} = 1 },
        }, @args ]) };

    my $res = $c->forward('/search/tags/name_regexp', $reqspec, $args[0]);
    if (!@{ $res }) {
        return $c->stash->{xmlrpc} = {
            message => [ 'Nothing match `' . $args[0] . '\'' ]
        };
    } else {
        my @message = 'rpm name matching `' . $args[0] . '\':';
        while (@{ $res }) {
            my $str = '';
            do {
                my $item = shift(@{ $res }) or last;
                $str .= ', ' if ($str);
                $str .= $item->{name};
            } while (length($str) < 70);
            push(@message, $str);
        }
        return $c->stash->{xmlrpc} = {
            message => \@message,
        };
    }
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

    if (!$c->forward('/distrib/exists', [ $reqspec ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have such distribution" ]
        };
    }

    my $rpmlist = $c->forward('/search/rpm/byname', [ $reqspec, $args[0] ]);
    if (!@{ $rpmlist }) {
        my $else = $c->forward('_find_rpm_elsewhere', [ $reqspec, $args[0] ]);
        if ($else) {
            return $c->stash->{xmlrpc} = {
                message => [ 
                    "The rpm named `$args[0]' has not been found but found in " . $else
                ],
            }
        } else {
            return $c->stash->{xmlrpc} = {
                message => [ "The rpm named `$args[0]' has not been found" ],
            }
        }
    }
    foreach (@{ $rpmlist }) {
        my $info = $c->forward('/rpms/basicinfo', [ $_ ]);
        push @message, $info->{evr} . ' // ' .
            $c->forward('_fmt_location', [ $reqspec, $_ ]);
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

=head2 v

C<v> is an alias for L<version> command.

=cut

sub v : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('version', [ @args ]);
}

=head2 summary [-s] NAME

Show the summary of package C<NAME>.

=cut

sub summary : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{summary}' ]);
}

=head2 s

Is an alias for C<summary> command.

=cut

sub s : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('summary', [ @args ]);
}

=head2 packager [-s] NAME

Show the packager of package C<NAME>.

=cut

sub packager : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{packager}' ]);
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

    $c->forward('qf', [ $reqspec, @args, '%{arch}' ]);
}

=head2 a

Is an alias to C<arch> command.

=cut 

sub a : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('arch', [ @args ]);
}

=head2 url [-s] NAME

Show the url of package C<NAME>.

=cut 

sub url : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{url}' ]);
}

=head2 u

Is an alias to C<url> command.

=cut 

sub u : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('url', [ @args ]);
}

=head2 group [-s] NAME

Show the group of package C<NAME>.

=cut 

sub group : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{group}' ]);
}

=head2 g

Is an alias to C<group> command.

=cut 

sub g : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('group', [ @args ]);
}

=head2 license [-s] NAME

Show the license of package C<NAME>.

=cut 

sub license : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{license}' ]);
}

=head2 l

Is an alias to C<license> command.

=cut 

sub l : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('license', [ @args ]);
}

=head2 buildtime [-s] NAME

Show the build time of package C<NAME>.

=cut

sub buildtime : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{buildtime:date}' ]);
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

=head2 cookie [-s] NAME

Show the C<cookie> tag of package C<NAME>.

=cut

sub cookie : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{cookie}' ]);
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

    @args == 2 or do {
        $c->error('No argument given');
        return;
    };

    if (!$c->forward('/distrib/exists', [ $reqspec ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have such distribution" ]
        };
    }

    my $rpmlist = $c->forward('/search/rpm/byname', [ $reqspec, $args[0] ]);
    if (!@{ $rpmlist }) {
        my $else = $c->forward('_find_rpm_elsewhere', [ $reqspec, $args[0] ]);
        if ($else) {
            return $c->stash->{xmlrpc} = {
                message => [ 
                    "The rpm named `$args[0]' has not been found but found in " . $else
                ],
            }
        } else {
            return $c->stash->{xmlrpc} = {
                message => [ "The rpm named `$args[0]' has not been found" ],
            }
        }
    }
    foreach (@{ $rpmlist }) {
        my $info = $c->forward('/rpms/queryformat', [ $_, $args[1] ]);
        push @message, $info . ' // ' .
            $c->forward('_fmt_location', [ $reqspec, $_ ]);
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

=head2 more NAME

Show url where details about package named C<NAME> can be found

=cut

sub more : XMLRPC {
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

    if (!$c->forward('/distrib/exists', [ $reqspec ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have such distribution" ]
        };
    }

    my $rpmlist = $c->forward('/search/rpm/byname', [ $reqspec, $args[0] ]);
    if (!@{ $rpmlist }) {
        my $else = $c->forward('_find_rpm_elsewhere', [ $reqspec, $args[0] ]);
        if ($else) {
            return $c->stash->{xmlrpc} = {
                message => [ 
                    "The rpm named `$args[0]' has not been found but found in " . $else
                ],
            }
        } else {
            return $c->stash->{xmlrpc} = {
                message => [ "The rpm named `$args[0]' has not been found" ],
            }
        }
    }
    foreach (@{ $rpmlist }) {
        push @message, $c->uri_for('/rpms', $_) . ' // ' .
            $c->forward('_fmt_location', [ $reqspec, $_ ]);
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }
}

=head2 buildfrom NAME

Return the list of package build from source package named C<NAME>

=cut

sub buildfrom : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;
    $reqspec->{src} = 1;
    my @message;
    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
        }, @args ]) };
    if (!$c->forward('/distrib/exists', [ $reqspec ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have such distribution" ]
        };
    }
    my $rpmlist = $c->forward('/search/rpm/byname', [ $reqspec, $args[0] ]);
    if (!@{ $rpmlist }) {
        my $else = $c->forward('_find_rpm_elsewhere', [ $reqspec, $args[0] ]);
        if ($else) {
            return $c->stash->{xmlrpc} = {
                message => [ 
                    "The rpm named `$args[0]' has not been found but found in " . $else
                ],
            }
        } else {
            return $c->stash->{xmlrpc} = {
                message => [ "The rpm named `$args[0]' has not been found" ],
            }
        }
    }
    foreach (@{ $rpmlist }) {
        my $res = $c->forward('/rpms/binaries', [ $_ ]);
        my @name;
        foreach (@$res) {
            push(@name, $c->forward('/rpms/basicinfo', [ $_ ])->{name});
        }
        push(@message, join(', ', sort @name));
    }
    return $c->stash->{xmlrpc} = {
        message => \@message,
    }

}

=head2 findfile FILE

Return the rpm owning the file C<FILE>. 

=cut

sub findfile : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    my @message;
    $reqspec->{src} = 0;

    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
        }, @args ]) };

    if (!$c->forward('/distrib/exists', [ $reqspec ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have such distribution" ]
        };
    }

    my $rpmlist = $c->forward('/search/rpm/byfile', [ $reqspec, $args[0] ]);
    if (!@{ $rpmlist }) {
        return $c->stash->{xmlrpc} = {
            message => [ "Sorry, no file $args[0] found" ],
        }
    } elsif (@{ $rpmlist } > 20) {
        foreach (@{ $rpmlist }) {
            my $info = $c->forward('/rpms/basicinfo', [ $_ ]);
            push @message, $info->{name} . ' // ' .
                $c->forward('_fmt_location', [ $reqspec, $_ ]);
        }
        return $c->stash->{xmlrpc} = {
            message => \@message,
        }
    } else {
        my %list;
        foreach (@{ $rpmlist }) {
            my $info = $c->forward('/rpms/basicinfo', [ $_ ]);
            $list{$info->{name}} = 1;
        }
        return $c->stash->{xmlrpc} = {
            message => [ join(', ', sort keys %list) ],
        };
    }
}

sub what : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;
        
    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
            's'   => \$reqspec->{src},
        }, @args ]) };

    my ($type, $depname, $sense, $evr) = @args;

    my $deptype = uc(substr($type, 0, 1));
    my $rpmlist = $c->forward('/search/rpm/bydep',
        [ $reqspec, $deptype, $depname, $sense, $evr ]);

    if (@{ $rpmlist } < 20) {
        my @name;
        foreach (@{ $rpmlist }) {
            my $info = $c->forward('/rpms/basicinfo', [ $_ ]);
            push @name, $info->{name} . '-' . $info->{evr};
        }
        return $c->stash->{xmlrpc} = {
            message => [
                "Package matching $depname" . ($evr ? " $sense $evr" : '') .
                ':', 
                join(' ', @name),
            ],
        }
    } else {
        return $c->stash->{xmlrpc} = {
            message => [ 'Too many result' ],
        };
    }

}

=head2 maint RPMNAME

Show the maintainers for the rpm named C<RPMNAME>.

=cut

sub maint : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;
    $reqspec->{src} = 0;
    my @message;
    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
        }, @args ]) };
    if (!$c->forward('/distrib/exists', [ $reqspec ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have such distribution" ]
        };
    }
    my $rpmlist = $c->forward('/search/rpm/byname', [ $reqspec, $args[0] ]);
    if (!@{ $rpmlist }) {
        my $else = $c->forward('_find_rpm_elsewhere', [ $reqspec, $args[0] ]);
        if ($else) {
            return $c->stash->{xmlrpc} = {
                message => [ 
                    "The rpm named `$args[0]' has not been found but found in " . $else
                ],
            }
        } else {
            return $c->stash->{xmlrpc} = {
                message => [ "The rpm named `$args[0]' has not been found" ],
            }
        }
    }
    my %maint;
    foreach (@{ $rpmlist }) {
        my $res = $c->forward('/rpms/maintainers', [ $_ ]);
        foreach (@$res) {
            my $m = 'For ' . $_->{vendor} . ': ' . $_->{owner};
            $maint{$m} = 1;
        }
    }
    return $c->stash->{xmlrpc} = {
        message => [ sort keys %maint ],
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
