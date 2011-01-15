package Sophie::Controller::Rpms;
use Moose;
use namespace::autoclean;
use Encode::Guess;
use Encode;
use POSIX;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Rpms - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect('/');
}

=head2 rpms.queryformat( PKGID, FORMAT )

Perform an C<rpm -q --qf> on the package having C<PKGID>.

=cut

sub queryformat : XMLRPCLocal {
    my ( $self, $c, $pkgid, $qf ) = @_;
    $c->stash->{xmlrpc} = $c->model('base')->resultset('Rpms')->search(
        { pkgid => $pkgid },
        { 
            select => [ qq{rpmqueryformat("header", ?)} ],
            as => [ 'qf' ],
            bind => [ $qf ],
        }
    )->next->get_column('qf');
}

=head2 rpms.tag( PKGID, TAG )

Return the list of C<TAG> values for package C<PKGID>

=cut

sub tag : XMLRPCLocal {
    my ( $self, $c, $pkgid, $tag ) = @_;
    $c->stash->{xmlrpc} = [ map { $_->get_column('tag') } $c->model('Base')->resultset('Rpms')->search(
        { pkgid => $pkgid },
        { 
            select => [ qq{rpmquery("header", rpmtag(?))} ],
            as => [ 'tag' ],
            bind => [ $tag ], 
        }
    )->all ]
}

=head2 rpms.basicinfo( PKGID )

Return a struct about basic informations about rpm having pkgid C<PKGID>.

Example of information return:

    {
          'arch' => 'x86_64',
          'version' => '0.0.3',
          'src' => '1',
          'issrc' => '1',
          'name' => 'ecap-samples',
          'release' => '1mdv2010.2',
          'description' => 'The sample contains three basic adapters.',
          'pkgid' => 'aa17ce95dd816e0817da78d7af54abdb',
          'summary' => 'Simple ecap samples',
          'filename' => 'ecap-samples-0.0.3-1mdv2010.2.src.rpm',
          'evr' => '0.0.3-1mdv2010.2'
    };

=head2 Url: /rpms/<PKGID>/basicinfo?json

Return a struct about basic informations about rpm having pkgid C<PKGID>.

Example of information return:

    {
          'arch' => 'x86_64',
          'version' => '0.0.3',
          'src' => '1',
          'issrc' => '1',
          'name' => 'ecap-samples',
          'release' => '1mdv2010.2',
          'description' => 'The sample contains three basic adapters.',
          'pkgid' => 'aa17ce95dd816e0817da78d7af54abdb',
          'summary' => 'Simple ecap samples',
          'filename' => 'ecap-samples-0.0.3-1mdv2010.2.src.rpm',
          'evr' => '0.0.3-1mdv2010.2'
    };

NB: This url works only in JSON format.

=cut

sub basicinfo :XMLRPCLocal :Chained('rpms_') :PathPart('basicinfo') :Args(0) {
    my ($self, $c, $pkgid) = @_;
    $pkgid ||= $c->stash->{pkgid};

    my $rpm = $c->model('base::Rpms')->find(
        { pkgid => $pkgid },
    );
    $rpm or return;
    my %info = $rpm->get_columns;
    $info{src} = $info{issrc} ? 1 : 0;
    foreach (qw(version release arch)) {
        if (my $r = $c->model('base')->resultset('Rpms')->search(
            { pkgid => $pkgid },
            { 
                select => [ qq{rpmquery("header", ?)} ],
                as => [ 'qf' ],
                bind => [ $_ ],
            }
            )->next) { 
            $info{$_} = $r->get_column('qf');
        }
    }
    $info{filename} = $c->forward('queryformat',
        [ $pkgid,
            '%{NAME}-%{VERSION}-%{RELEASE}.%|SOURCERPM?{%{ARCH}}:{src}|.rpm'
        ]);

    return $c->stash->{xmlrpc} = \%info;
}

=head2 rpms.info( PKGID )

Like rpms.basicinfo return a struct containing single information about the request rpm.

=head2 Url: /rpms/<PKGID>/info?json

Like rpms/<PKGID>basicinfo return a struct containing single information about the request rpm.

NB: This url works only in JSON format.

=cut

sub info : XMLRPCLocal :Chained('rpms_') :PathPart('info') :Args(0) {
    my ($self, $c, $pkgid) = @_;
    $pkgid ||= $c->stash->{pkgid};

    my $info = $c->forward('basicinfo', [ $pkgid ]);
    foreach (qw(name epoch url group size packager
                url sourcerpm license buildhost
                distribution)) {
        if (my $r = $c->model('base')->resultset('Rpms')->search(
            { pkgid => $pkgid },
            { 
                select => [ qq{rpmquery("header", ?)} ],
                as => [ 'qf' ],
                bind => [ $_ ],
            }
            )->next) { 
            $info->{$_} = $r->get_column('qf');
        }
    }

    return $c->stash->{xmlrpc} = $info;
}

=head2 rpms.dependency(PKGID, DEPTYPE)

Return a list of C<DEPTYPE> dependencies for package C<PKGID> where C<DEPTYPE>
is one of:

=over 4

=item C<P> for Provides

=item C<R> for Requires

=item C<C> for Conflicts

=item C<O> for Obsoletes

=item C<E> for Enhanced

=item C<S> for Suggests

=back

=cut

sub xmlrpc_dependency : XMLRPCPath('dependency') {
    my ($self, $c, @args) = @_;
    $c->forward('dependency', [ @args ]);
}

=head2 Url: /rpms/<PKGID>/dependency/<DEPTYPE>?json

Return a list of C<DEPTYPE> dependencies for package C<PKGID> where C<DEPTYPE>
is one of:

=over 4

=item C<P> for Provides

=item C<R> for Requires

=item C<C> for Conflicts

=item C<O> for Obsoletes

=item C<E> for Enhanced

=item C<S> for Suggests

=back

=cut

sub dependency :XMLRPC :Chained('rpms_') :PathPart('dependency') :Args(1) {
    my ($self, $c, $pkgid, $deptype) = @_;
    if (!$deptype) {
        $deptype = $pkgid;
        $pkgid = $c->stash->{pkgid};
    }

    $c->stash->{xmlrpc} = [ 
        map { 
            { 
                name => $_->get_column('depname'),
                flags => $_->get_column('flags'),
                evr => $_->get_column('evr'),
                sense => $_->get_column('sense'),
            }
        } 
        $c->model('Base')->resultset('Deps')->search(
            { 
                pkgid => $pkgid,
                deptype => $deptype,
            },
            { 
                order_by => [ 'count' ],
                select => [ 'rpmsenseflag("flags")', qw(depname flags evr) ],
                as => [ qw'sense depname flags evr' ],

            },
        )->all ];
}

sub sources : XMLRPCLocal {
    my ( $self, $c, $pkgid ) = @_;

    my $sourcerpm = $c->forward('queryformat', [ $pkgid, '%{SOURCERPM}' ]);
    my $nosourcerpm = $sourcerpm;
    $nosourcerpm =~ s/\.src.rpm$/\.nosrc.rpm/;

    $c->stash->{xmlrpc} = [ $c->model('Base::Rpms')->search(
        {
            pkgid => { 
                IN => $c->model('Base::RpmFile')->search(
                    { filename => [ $sourcerpm, $nosourcerpm ] }
                )->get_column('pkgid')->as_query
            },
        }
    )->get_column('pkgid')->all ];
}

sub binaries : XMLRPCLocal {
    my ( $self, $c, $pkgid ) = @_;

    my $sourcerpm = $c->forward('queryformat', [ $pkgid,
            '%{NAME}-%{VERSION}-%{RELEASE}.src.rpm' ]);
    my $nosourcerpm = $sourcerpm;
    $nosourcerpm =~ s/\.src.rpm$/\.nosrc.rpm/;

    my $tagrs = $c->model('Base')->resultset('Tags')
        ->search({ tagname => 'sourcerpm', value => [ $sourcerpm, $nosourcerpm ] })
        ->get_column('pkgid');
    $c->stash->{xmlrpc} = [ $c->model('Base::Rpms')->search(
        {
            -and => [
                { issrc => 0 },
                { pkgid =>
                    { IN => $tagrs->as_query, },
                },
            ]
        },
        {
            order_by => [ qw(arch name), 'evr using >>' ],
        },
    )->get_column('pkgid')->all ];

}


=head2 rpms.maintainers( PKGID )

Return the maintainers for this package.

The list of maintainers is limited to distribution where the package is located.

If the package is a binary the C<SOURCERPM> tag is used to find the source rpm
name.

=cut

sub maintainers : XMLRPCLocal {
    my ($self, $c, $pkgid) = @_;

    my $binfo = $c->forward('/rpms/basicinfo', [ $pkgid ]);
    my $rpmname;
    if ($binfo->{issrc}) {
        $rpmname = $binfo->{name};
    } else {
        my $sourcerpm = $c->forward('queryformat', [ $pkgid, '%{SOURCERPM}' ]);
        $sourcerpm =~ /^(.*)-([^-]+)-([^-]+)\.[^\.]+.rpm$/;
        $rpmname = $1;
    }
    my %dist;
    foreach (@{ $c->forward('/rpms/location', [ $pkgid ]) }) {
        $dist{$_->{distribution}} = 1;
    }

    $c->forward('/maintainers/byrpm', [ $rpmname, [ keys %dist ] ]);
}

sub rpms_ :PathPrefix :Chained :CaptureArgs(1) {
    my ( $self, $c, $pkgid ) = @_;
    $c->stash->{pkgid} = $pkgid if($pkgid);
    {
        my $match = $c->stash->{pkgid};
    }
    if (!$c->model('Base::Rpms')->find({ pkgid => $c->stash->{pkgid} })) {
        $c->go('/404/index');
    }
    my $info = $c->stash->{rpms}{info} =
        $c->forward('info', [ $c->stash->{pkgid} ]);

    $c->stash->{metatitle} = sprintf("%s-%s %s",
        $info->{name},
        $info->{evr},
        $info->{issrc} ? 'src' : $info->{arch},
    );
    push(@{ $c->stash->{keywords} }, $info->{name}, $info->{evr},
        $info->{issrc} ? 'src' : $info->{arch},);
    $c->stash->{metarevisit} = 30;

    # for later usage, keep history of visited rpms
    $c->session->{visited_rpms}{$c->stash->{pkgid}} = time;
    if (keys %{ $c->session->{visited_rpms} } > 20) {
        my @visited = sort
        { $c->session->{visited_rpms}{$b} <=> $c->session->{visited_rpms}{$a} }
        keys %{ $c->session->{visited_rpms} };
        splice(@visited, 0, 20);
        delete $c->session->{visited_rpms}{$_} foreach (@visited);
    }

    $c->stash->{rpms}{location} =
        $c->forward('location', [ $c->stash->{pkgid} ]);
}

sub rpms : Private {
    my ( $self, $c, $pkgid, $subpart, @args) = @_;
    # Because $c->forward don't take into account Chained sub
    $c->forward('rpms_', [ $pkgid ]);
    for ($subpart || '') {
        /^deps$/       and $c->go('deps',        [ $pkgid, @args ]);
        /^files$/      and $c->go('files',       [ $pkgid, @args ]);
        /^changelog$/  and $c->go('changelog',   [ $pkgid, @args ]);
        /^location$/   and $c->go('location',    [ $pkgid, @args ]);
        /^basicinfo$/  and $c->go('basicinfo',   [ $pkgid, @args ]);
        /^info$/       and $c->go('info',        [ $pkgid, @args ]);
        /^analyse$/    and $c->go('analyse',     [ $pkgid, @args ]);
        /^dependency$/ and $c->go('dependency',  [ $pkgid, @args ]);
        /^history$/    and $c->go('history',  [ $pkgid, @args ]);
        /^query$/      and $c->go('query',       [ $pkgid, @args ]);
        /./            and $c->go('/404/index'); # other subpart dont exists
    }
    $c->stash->{rpmurl} = $c->req->path;

    return $c->stash->{xmlrpc} = $c->stash->{rpms};
}

sub rpms__ : Chained('/rpms/rpms_') :PathPart('') :Args(0) {
    my ( $self, $c ) = @_;

    $c->go('rpms', [ $c->stash->{pkgid} ]);
}


sub deps :Chained('rpms_') :PathPart('deps') :Args(0) :XMLRPCLocal {
    my ( $self, $c, $pkgid ) = @_;
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+:)[0];
    $pkgid ||= $c->stash->{pkgid};

    my %deps;
    foreach (
        $c->model('Base')->resultset('Deps')->search(
            { 
                pkgid => $pkgid,
            },
            { 
                order_by => [ 'count' ],
                select => [ 'rpmsenseflag("flags")',
                    qw(depname flags evr deptype) ],
                as => [ qw'sense depname flags evr deptype' ],

            },
        )->all) {
        push( @{ $deps{$_->get_column('deptype')} },
            {
                name => $_->get_column('depname'),
                flags => $_->get_column('flags'),
                evr => $_->get_column('evr'),
                sense => $_->get_column('sense'),
            }
        );
    }
    $c->stash->{xmlrpc} = \%deps;
}

sub files :Chained('rpms_') :PathPart('files') :Args(0) :XMLRPCLocal {
    my ( $self, $c, $pkgid, $number ) = @_;
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+:)[0];
    $pkgid ||= $c->stash->{pkgid};

    if ($number) { # This come from a forward
        $c->go('files_contents', [ $number ]);
    }

    my @col = qw(dirname basename md5 size count);
    $c->stash->{xmlrpc} = [ map {
        {
            filename => $_->get_column('dirname') . $_->get_column('basename'),
            dirname => $_->get_column('dirname'),
            basename => $_->get_column('basename'),
            md5 => $_->get_column('md5'),
            perm => $_->get_column('perm'),
            size => $_->get_column('size'),
            user => $_->get_column('user'),
            group => $_->get_column('group'),
            has_content => $_->get_column('has_content'),
            count => $_->get_column('count'),
        }
    } $c->model('Base')->resultset('Files')->search(
            { 
                pkgid => $pkgid,
            },
            { 
                'select' => [ 'contents is NOT NULL as has_content', 'rpmfilesmode(mode) as perm', @col, '"group"',
                    '"user"' ],
                as => [ qw(has_content perm), @col, 'group', 'user' ],
                order_by => [ 'dirname', 'basename' ],

            },
        )->all ];
}

sub files_contents :Chained('rpms_') :PathPart('files') :Args(1) {
    my ( $self, $c, $number ) = @_;
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+/[^/]+:)[0];
    my $pkgid = $c->stash->{pkgid};

    $c->stash->{xmlrpc} = $c->model('Base::Files')->search(
        {
            pkgid => $pkgid,
            count => $number,
        },
        {
            select => ['contents'],
        }
    )->get_column('contents')->first;
}

sub changelog :Chained('rpms_') :PathPart('changelog') :Args(0) :XMLRPCLocal {
    my ( $self, $c, $pkgid ) = @_;
    $pkgid ||= $c->stash->{pkgid};
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+:)[0];

    my @ch;
    foreach ($c->model('Base')->resultset('RpmsChangelog')->search({},
            { 
                bind => [ $pkgid ],
                order_by => [ 'time::int desc' ],
            },
        )->all) {
        my $chentry;
        my $enc = guess_encoding($_->get_column('text'), qw/latin1/);
        $chentry->{text} = $enc && ref $enc
            ? encode('utf8', $_->get_column('text'))
            : $_->get_column('text');
        $enc = guess_encoding($_->get_column('name'), qw/latin1/);
        $chentry->{name} = $enc && ref $enc
            ? encode('utf8', $_->get_column('name'))
            : $_->get_column('name');
        $chentry->{time} = $_->get_column('time');
        $chentry->{date} = POSIX::strftime('%a %b %e %Y', gmtime($_->get_column('time')));
        push(@ch, $chentry);
    }

    $c->stash->{xmlrpc} = \@ch;
}

=head2 rpms.location( PKGID )

Return all distribution where the package having C<PKGID> can be found.

=cut

sub location :Chained('rpms_') :PathPart('location') :Args(0) {
    my ( $self, $c, $pkgid ) = @_;
    $pkgid ||= $c->stash->{pkgid};
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+:)[0];

    $c->stash->{xmlrpc} = [
        map {
        {
            distribution => $_->get_column('name'),
            dist => $_->get_column('shortname'),
            release => $_->get_column('version'),
            arch => $_->get_column('arch'), 
            media => $_->get_column('label'),
            media_group => $_->get_column('group_label'),
        }
        }
        $c->forward('/distrib/distrib_rs', [ {} ])
         ->search_related('MediasPaths')
                 ->search_related('Paths')
        ->search_related('Rpmfiles',
            { pkgid => $pkgid },
            {
                select => [ qw(shortname name version arch label group_label) ],
                order_by => [ qw(name version arch label) ],
            }
        )->all ]
}

sub analyse :Chained('rpms_') :PathPart('analyse') :Args(0) :XMLRPC {
    my ( $self, $c, $pkgid, $dist ) = @_;
    $pkgid ||= $c->stash->{pkgid};
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+:)[0];
    $dist->{distribution} ||= $c->req->param('distribution');
    $dist->{release} ||= $c->req->param('release');
    $dist->{arch} ||= $c->req->param('arch');
    if ($c->req->param('start')) {
        $c->session->{analyse} = $dist;
    } elsif (! $c->req->xmlrpc->is_xmlrpc_request) {
        $dist = $c->session->{analyse};
    }

    if ($c->req->param('analyse') || $c->req->xmlrpc->is_xmlrpc_request) {

        my @deplist = map {
            [ $_->{name}, $_->{sense}, $_->{evr} ]
        } @{ $c->forward('dependency', [ $pkgid, 'R' ]) };

        $c->stash->{xmlrpc} = $c->forward(
            '/analysis/solver/solve_dependencies',
            [ $dist,
                'P', \@deplist, [] ]
        );
    } else {
        $c->stash->{xmlrpc} = '';
    }
}

sub history :Chained('rpms_') :PathPart('history') :Args(0) :XMLRPC {
    my ( $self, $c, $pkgid, $dist ) = @_;
    $pkgid ||= $c->stash->{pkgid};
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+:)[0];

    my $highter = $c->forward('/search/rpm/byname', [
            { rows => 5, src => $c->stash->{rpms}{info}{issrc} },
            $c->stash->{rpms}{info}{name}, '>', $c->stash->{rpms}{info}{version} ]);
    my $lesser = $c->forward('/search/rpm/byname', [
            { rows => 5, src => $c->stash->{rpms}{info}{issrc} },
            $c->stash->{rpms}{info}{name}, '<', $c->stash->{rpms}{info}{version} ]);
    $c->stash->{xmlrpc} = {
        highter => $highter,
        older => $lesser,
    };
}

# compat URL:
sub query :Chained('rpms_') :PathPart('analyse') :Args(0) {
    my ( $self, $c, $pkgid, $dist ) = @_;
    $pkgid ||= $c->stash->{pkgid};
    $c->stash->{rpmurl} = ($c->req->path =~ m:(.*)/[^/]+:)[0];
    $c->res->redirect($c->uri_for('/', $c->stash->{rpmurl}, 'analyse'));
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
