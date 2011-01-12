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
                    src => $searchspec->{src},
                    rows => 1,
                }, $name ]);
        if (@{$rpmlist}) {
            return $c->forward('_fmt_location', [ { 
                        distribution => $searchspec->{distribution}
                    }, $rpmlist->[0] ]);
        }
    }
    my $rpmlist = $c->forward('/search/rpm/byname', [ { src =>
                $searchspec->{src}}, $name ]);
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

=head2 list [distribution [release [arch]]]

List available distribution, release, architecture matching given arguments.

=cut

sub list : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    my $distrib = {
        distribution => $args[0],
        release      => $args[1],
        arch         => $args[2],
    };

    if (!$c->forward('/distrib/exists', [ $distrib ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have any distribution matching: "
                         . join(' / ', grep { $_ } @args[0..2]) ],
        };
    }

    my @list = @{ $c->forward('/distrib/list', [ $distrib ]) };
    return $c->stash->{xmlrpc} = {
        message => [ 
            ($args[0] 
                ? join(' / ', grep { $_ } @args[0..2]) . ': '
                : '') .
            join(', ', @list) ],
    }
}

=head2 q [-d distrib] [-r release] [-a arch] [-s]  REGEXP

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
            'r=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
            's'   => sub { $reqspec->{src} = 1 },
        }, @args ]) };

    my $res = $c->forward('/search/tags/name_regexp', $reqspec, $args[0]);
    warn join(' ', @{ $res });
    if (!@{ $res }) {
        return $c->stash->{xmlrpc} = {
            message => [ 'Nothing match `' . $args[0] . '\'' ]
        };
    } else {
        my @message = 'rpm name matching `' . $args[0] . '\':';
        while (@{ $res }) {
            my $str = '';
            while (length($str) < 70) {
                my $item = shift(@{ $res }) or last;
                $str .= ', ' if ($str);
                $str .= $item->{name};
            }
            push(@message, $str);
        }
        return $c->stash->{xmlrpc} = {
            message => \@message,
        };
    }
}

=head2 whatis [-d distrib] [-r release] [-a arch] [-s]  WORD [WORD2 [...]]

Search rpm having description containing words given as arguments

=cut

sub whatis : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $reqspec->{src} = 0;

    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'r=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
            's'   => sub { $reqspec->{src} = 1 },
        }, @args ]) };
    my $res = $c->forward('/search/rpm/description', [ $reqspec, @args ]);

    if (@{ $res }) {
        if (@{ $res } > 100) {
            return $c->stash->{xmlrpc} = {
                message => [ 'I have ' . @{ $res } . ' results' ],
            };
        } else {
            my @names = ();
            foreach (@{ $res }) {
                my $info = $c->forward('/rpms/basicinfo', [ $_ ]);
                push(@names, $info->{name});
            }
            my @message = 'rpm name matching `' . $args[0] . '\':';
            while (@names) {
                my $str = '';
                while (length($str) < 70) {
                    my $item = shift(@names) or last;
                    $str .= ', ' if ($str);
                    $str .= $item;
                }
                push(@message, $str);
            }
            return $c->stash->{xmlrpc} = {
                message => \@message,
            };
        }
    } else {
        return $c->stash->{xmlrpc} = {
            message => [ 'No rpm description matches this keywords' ],
        };
    }
}

=head2 version [-d distrib] [-r release] [-a arch] [-s] NAME

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
            'r=s' => \$reqspec->{release},
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
                    "There is no rpm named `$args[0]', but the word matches in " . $else
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

C<v> is an alias for C<version> command.

=cut

sub v : XMLRPC {
    my ($self, $c, @args) = @_;
    $c->forward('version', [ @args ]);
}

=head2 summary [-d distrib] [-r release] [-a arch] [-s]  NAME

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

=head2 packager [-d distrib] [-r release] [-a arch] [-s]  NAME

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

=head2 arch [-d distrib] [-r release] [-a arch] [-s]  NAME

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

=head2 url [-d distrib] [-r release] [-a arch] [-s]  NAME

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

=head2 group [-d distrib] [-r release] [-a arch] [-s] NAME

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

=head2 license [-d distrib] [-r release] [-a arch] [-s] NAME

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

=head2 buildtime [-d distrib] [-r release] [-a arch] [-s] NAME

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

=head2 cookie [-d distrib] [-r release] [-a arch] [-s]  NAME

Show the C<cookie> tag of package C<NAME>.

=cut

sub cookie : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{cookie}' ]);
}

=head2 sourcerpm [-d distrib] [-r release] [-a arch] [-s] NAME

Show the C<sourcerpm> tag of package C<NAME>.

=cut

sub sourcerpm : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{sourcerpm}' ]);
}

=head2 src NAME

Is an alias for C<sourcerpm> command.

=cut

sub src : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('sourcerpm', [ $reqspec, @args ]);
}

=head2 rpmversion [-d distrib] [-r release] [-a arch] [-s] NAME

Show the C<rpmversion> tag of package C<NAME>.

=cut

sub rpmversion : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{rpmversion}' ]);
}

=head2 rpmbuildversion NAME

Is an alias for C<rpmversion> command.

=cut

sub rpmbuildversion : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('rpmversion', [ $reqspec, @args ]);
}


=head2 buildhost [-d distrib] [-r release] [-a arch] [-s] NAME

Show the C<buildhost> tag of package C<NAME>.

=cut

sub buildhost : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{buildhost}' ]);
}

=head2 host NAME

Is an alias for C<buildhost> command.

=cut

sub host : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('host', [ $reqspec, @args ]);
}

=head2 h NAME

Is an alias for C<buildhost> command.

=cut

sub h : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('host', [ $reqspec, @args ]);
}



=head2 distribution [-d distrib] [-r release] [-a arch] [-s] NAME

Show the C<distribution> tag of package C<NAME>.

=cut

sub distribution : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{distribution}' ]);
}

=head2 distrib NAME

Is an alias for C<distribution> command.

=cut

sub distrib : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('distribution', [ $reqspec, @args ]);
}



=head2 vendor [-d distrib] [-r release] [-a arch] [-s] NAME

Show the C<vendor> tag of package C<NAME>.

=cut

sub vendor : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;

    $c->forward('qf', [ $reqspec, @args, '%{vendor}' ]);
}

=head2 qf [-d distrib] [-r release] [-a arch] [-s] NAME FMT

Perform an rpm -q --qf C<FMT> on package C<NAME>.

=cut

sub qf : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;
    my @message;
    $reqspec->{src} = 0;

    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'r=s' => \$reqspec->{release},
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
                    "There is no rpm named `$args[0]', but the word matches in " . $else
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

=head2 more [-d distrib] [-r release] [-a arch] [-s]  NAME

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
            'r=s' => \$reqspec->{release},
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
                    "There is no rpm named `$args[0]', but the word matches in " . $else
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

=head2 buildfrom [-d distrib] [-r release] [-a arch] NAME

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
            'r=s' => \$reqspec->{release},
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
                    "There is no rpm named `$args[0]', but the word matches in " . $else
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

=head2 findfile [-d distrib] [-r release] [-a arch] [-s] FILE

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
            'r=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
            's'   => \$reqspec->{src},
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

=head2 what [-d distrib] [-r release] [-a arch] [-s] p|r|c|o|e|s DEP [SENSE [EVR]]

Search rpm matching having matching dependencies (provides, requires, conflicts,
obsoletes, enhanced or suggests)

=cut

sub what : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;
        
    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$reqspec->{distribution},
            'v=s' => \$reqspec->{release},
            'r=s' => \$reqspec->{release},
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

=head2 maint [-d distrib] [-r release] [-a arch] [-s] RPMNAME

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
            'r=s' => \$reqspec->{release},
            'a=s' => \$reqspec->{arch},
            's'   => \$reqspec->{src},
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
                    "There is no rpm named `$args[0]', but the word matches in " . $else
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

=head2 nb_rpm [-d distrib] NAME

Show the count of rpm maintains by packager matching C<NAME>.

=cut

sub nb_rpm : XMLRPC {
    my ($self, $c, $reqspec, @args) = @_;
    my @message;
    my $dist = { distribution => $reqspec->{distribution} };
    @args = @{ $c->forward('_getopt', [
        {
            'd=s' => \$dist->{distribution},
        }, @args ]) };
    if (!$c->forward('/distrib/exists', [ $dist ])) {
        return $c->stash->{xmlrpc} = {
            message => [ "I don't have such distribution" ]
        };
    }

    my $maints = $c->forward('/maintainers/search',
        [ $args[0], $dist->{distribution} ]);
    if (@$maints > 3) {
        return $c->stash->{xmlrpc} = {
            message => [ 
                scalar(@$maints) . " maintainers found matching `$args[0]'"
            ]
        };
    } elsif (! @$maints) {
        return $c->stash->{xmlrpc} = {
            message => [ "No maintainers found matching `$args[0]'" ]
        };
    } else {
        my @messages;
        foreach (@$maints) {
            my $rpms = $c->forward('/maintainers/bymaintainer', [
                $_->{owner}, $dist->{distribution} ]);
            push(@messages, sprintf('%s (%s) maintains %d rpms',
                    $_->{owner},
                    $_->{vendor},
                    scalar(@$rpms),
                )
            );
        }
        return $c->stash->{xmlrpc} = {
            message => \@messages,
        };
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
