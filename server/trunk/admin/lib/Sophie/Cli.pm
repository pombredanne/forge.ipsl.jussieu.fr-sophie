package Sophie::Cli;

# $Id: Cli.pm 4321 2010-10-26 16:28:15Z nanardon $

use strict;
use warnings;
use Term::ReadLine;
use Text::ParseWords;
use Getopt::Long;
use RPC::XML;
$RPC::XML::FORCE_STRING_ENCODING = 1;

{
    open (my $fh, "/dev/tty" )
        or eval 'sub Term::ReadLine::findConsole { ("&STDIN", "&STDERR") }';
    die $@ if $@;
    close ($fh);
}

my $term = Term::ReadLine->new('LA CLI');
$term->MinLine(99999);
my $OUT = $term->OUT || \*STDOUT;

sub denv {
    my ($base, $dist, $vers, $arch) = @_;
    my $env = __PACKAGE__->new(
        {
            prompt => sub {
                sprintf('%s - %s - %s > ',
                    $_[0]->{dist}{distribution},
                    $_[0]->{dist}{release},
                    $_[0]->{dist}{arch},
                );
            },
            dist => {
                distribution => $dist,
                release => $vers,
                arch => $arch,
            },
        },
        $base,
    );

    $env->add_func('show', {
            code => sub {
                my ($self) = @_;

                my $res = $self->xmlreq('distrib.struct',
                    $self->{dist},
                );
                print $OUT join ('', map { "$_->{label}\n" } @{ $res->value });
            }
        }
    );

    $env->add_func('setpath', {
            code => sub {
                my ($self, $media, $path) = @_;
                my $res = $self->xmlreq('admin.media_path',
                    $self->{dist},
                    $media,
                    $path,
                );
            },
            completion => sub {
                my ($self, $start, $media) = @_;
                if ($media) {
                    my $res = $self->xmlreq('admin.ls_local', $start);
                    return @{ $res->value };
                } else {
                my $res = $self->xmlreq('distrib.struct',
                    $self->{dist},
                );
                return map { $_->{label} } @{ $res->value };
                }
            },
        }
    );
    $env->add_func('unsetpath', {
            code => sub {
                my ($self, $media, $path) = @_;
                my $res = $self->xmlreq('admin.media_remove_path',
                    $self->{dist},
                    $media,
                    $path,
                );
            },
            completion => sub {
                my ($self, $start, $media) = @_;
                if ($media) {
                    my $res = $self->xmlreq('admin.list_path',
                        $self->{dist},
                        $media,
                    );
                    return @{ $res->value };
                } else {
                my $res = $self->xmlreq('distrib.struct',
                    $self->{dist},
                );
                return map { $_->{label} } @{ $res->value };
                }
            },
        }
    );
    $env->add_func('listpath', {
            code => sub {
                my ($self, $media) = @_;
                my $res = $self->xmlreq('admin.list_path',
                    $self->{dist},
                    $media,
                );
                print $OUT join ('', map { "$_\n" } @{ $res->value });
            },
            completion => sub {
                my ($self, $start) = @_;
                my $res = $self->xmlreq('distrib.struct',
                    $self->{dist},
                );
                return map { $_->{label} } @{ $res->value };
            },
        }
    );
    $env->add_func('replace_path',
        {
            help => '',
            code => sub {
                my ($self, $path, $newpath) = @_;
                my $res = $self->xmlreq(
                    '/admin/replace_path', $path, $newpath);
                print $OUT join (' ', map { $_ } @{ $res->value });
                print $OUT "\n";
            },
            completion => sub {
                my ($self, $start, $oldpath) = @_;
                if ($oldpath) {
                    my $res = $self->xmlreq('admin.ls_local', $start);
                    return @{ $res->value };
                } else {
                    my $res = $self->xmlreq('admin.list_path',
                        $self->{dist},
                    );
                    return @{ $res->value };
                }
            },
        }
    );
    $env->add_func('remove_media',
        {
            help => '',
            code => sub {
                my ($self, $media) = @_;
                my $res = $self->xmlreq(
                    '/admin/remove_media', $self->{dist}, $media);
                print $OUT join (' ', map { $_ } @{ $res->value });
                print $OUT "\n";
            },
            completion => sub {
                my ($self) = @_;
                my $res = $self->xmlreq('distrib.struct',
                    $self->{dist},
                );
                return map { $_->{label} } @{ $res->value };
            },
        }
    );
    $env->add_func('addmedia', {
            code => sub {
                my ($self, $media, $group) = @_;
                my $res = $self->xmlreq('admin.add_media',$self->{dist},
                    { label => $media,
                      group_label => $group },
                );
                print $OUT join ('', map { "$_->{label}\n" } @{ $res->value });
            },
            completion => sub {
                my ($self, $start, $label) = @_;
                my $res = $self->xmlreq('distrib.struct',
                    $self->{dist},
                );
                return ((map { $_->{label} } @{ $res->value }), $label ?
                    ($label) : ())
            },
        }
    );


    $env
}

sub globalenv {
    my ($base) = @_;
    my $env = __PACKAGE__->new({}, $base);

    $env->add_func('create_user',
        {
            code => sub {
                my ($self, $user, $password) = @_;
                my $res = $self->xmlreq('admin.create_user', $user, $password);
                if ($res) {
                    print $OUT $res->value . "\n";
                }
            },
        }
    );
    $env->add_func('select',
        {
            code => sub {
                my ($self, $dist, $ver, $arch) = @_;
                if (!($dist && $ver && $arch)) {
                    print $OUT "missing argument\n";
                    return;
                }
                denv($self->base, $dist, $ver, $arch)->cli();
            },
            completion => sub {
                my ($self, undef, @args) = @_;
                my $res = $self->xmlreq(
                    'distrib.list', @args);
                return  map { $_ } @{$res->value};
            },
        },
    );
    $env->add_func('create',
        {
            code => sub {
                my ($self, $dist, $ver, $arch, $label, ) = @_;
                my $res = $self->xmlreq('admin.create', $dist, $ver, $arch);
                print $OUT join (' ', map { $_ } @{ $res->value });
            },
            completion => sub {
                my ($self, undef, @args) = @_;
                my $res = $self->xmlreq(
                    'distrib.list', @args);
                return  map { $_ } @{$res->value};
            },
        },
    );
    $env->add_func('content',
        { 
            help => '',
            code => sub {
                my ($self, $dist, $ver) = @_;
                my $res = $self->xmlreq(
                    'distrib.list', $dist, $ver);
                print $OUT join (' ', map { $_ } @{ $res->value });
            },
            completion => sub {
                my ($self, undef, @args) = @_;
                my $res = $self->xmlreq(
                    'distrib.list', @args);
                return  map { $_ } @{$res->value};
            },
        }
    );

    $env
}

sub new {
    my ($class, $env, $base) = @_;
    bless($env, $class);
    $env->{_base} = $base;
    $env->add_func('quit', { help => 'quit - exit the tool',
            code => sub { print "\n"; exit(0) }, });
    $env->add_func('exit', { help => "exit current mode",
            code => sub { return "EXIT" }, });
    $env->add_func('help', {
        help => 'help [command] - print help about command',
        completion => sub {
            if (!$_[2]) { return sort keys %{ $_[0]->{funcs} || {}} }
        },
        code => sub {
            my ($self, $name) = @_;
            if (!$name) {
                print $OUT join(', ', sort keys %{ $self->{funcs} || {}}) . "\n";
            } elsif ($self->{funcs}{$name}{alias}) {
                print $OUT "$name is an alias for " . join(' ',
                    @{$self->{funcs}{$name}{alias}}) . "\n";
            } elsif ($self->{funcs}{$name}{help}) {
                print $OUT $self->{funcs}{$name}{help} . "\n";
            } else {
                print $OUT "No help availlable\n";
            }
        },
    });

    $env;
}

sub base { $_[0]->{_base} }

sub cli {
    my ($self) = @_;
    while (1) {
        $term->Attribs->{completion_function} = sub {
            $self->complete($_[0], shellwords(substr($_[1], 0, $_[2])));
        };
        defined (my $line = $term->readline($self->prompt)) or do {
            print $OUT "\n";
            return;
        };
        $term->addhistory($line);
        my $res = $self->run(shellwords($line));
        $self->rollback;
        if ($res && $res eq 'EXIT') { print $OUT "\n"; return }
    }
}

sub prompt {
    my ($self) = @_;
    if (!$self->{prompt}) {
        return "LA cli > ";
    } else {
        $self->{prompt}->($self);
    }
}

sub add_func {
    my ($self, $name, $param) = @_;
    $self->{funcs}{$name} = $param;
}

sub getoption {
    my ($self, $opt, @args) = @_;
    local @ARGV = @args;
    Getopt::Long::Configure("pass_through");
    GetOptions(%{ $opt });

    return @ARGV;
}

sub parse_arg {
    my ($self, $name, @args) = @_;
    return @args;
}

sub complete {
    my ($self, $lastw, $name, @args) = @_;
    if (!$name) {
        return grep { /^\Q$lastw\E/ } sort
            (keys %{ $self->{funcs} || {}});
    } elsif ($self->{funcs}{$name}{alias}) {
        $self->complete($lastw, @{$self->{funcs}{$name}{alias}}, @args);
    } elsif ($self->{funcs}{$name}{completion}) {
        my @res;
        eval {
        my @pargs = $self->parse_arg($name, @args);
        @res = $self->{funcs}{$name}{completion}->($self, $lastw, @pargs);
        };
        return map { my $t = $_; $t =~ s/\s/\\ /g; $t } grep { $_ &&
            /^\Q$lastw\E/ } @res;
        
    } else {
        return ();
    }
}

sub run {
    my ($self, $name, @args) = @_;
    return if (!$name);
    if (!exists($self->{funcs}{$name})) {
        print $OUT "No command $name found\n";
    } elsif ($self->{funcs}{$name}{alias}) {
        $self->run(@{$self->{funcs}{$name}{alias}}, @args);
    } elsif ($self->{funcs}{$name}{code}) {
        eval {
        my @pargs = $self->parse_arg($name, @args);
        $self->{funcs}{$name}{code}->($self, @args);
        };
    } else {
        print $OUT "No command $name found\n";
    }
}

sub xmlreq {
    my ($self, $code, @args) = @_;
    my $res = $self->base->send_request(
        $code, @args,
    );
}

sub commit {
    my ($self) = @_;
}

sub rollback {
    my ($self) = @_;
}

1;
