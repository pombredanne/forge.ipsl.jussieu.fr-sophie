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

    $c->response->body('Matched Sophie::Controller::Rpms in Rpms.');
}

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


sub info : XMLRPCLocal {
    my ($self, $c, $pkgid) = @_;

    my %info = ( pkgid => $pkgid );
    foreach (qw(name version release epoch url group size packager
                url sourcerpm license buildhost
                arch distribution)) {
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
    my $rpm = $c->model('base')->resultset('Rpms')->search(
            { pkgid => $pkgid },
        )->next;
    $info{description} = $rpm->description;
    $info{summary} = $rpm->summary;
    $info{src} = $rpm->issrc ? 1 : 0;
    $info{evr} = $rpm->evr;

    return $c->stash->{xmlrpc} = \%info;
}


sub deps : XMLRPCLocal {
    my ($self, $c, $pkgid, $deptype) = @_;

    @{ $c->stash->{xmlrpc}{deps}{$deptype} } = 
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
        )->all;
}

=head2 rpms.location (PKGID)

Return all distribution where the package having C<PKGID> can be found.

=cut

sub location : XMLRPCLocal {
    my ($self, $c, $pkgid) = @_;

    $c->stash->{xmlrpc} = [
        map {
        {
            distribution => $_->get_column('name'),
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
                select => [ qw(name version arch label group_label) ],
            }
        )->all ]


}

sub rpms_ :PathPrefix :Chained :CaptureArgs(1) {
    my ( $self, $c, $pkgid ) = @_;
    $c->stash->{pkgid} = $pkgid if($pkgid);
    {
        my $match = $c->stash->{pkgid};
    }
    #$c->model('Base')->resultset('Rpms')->search(pkgid => $pkgid)->next;
    $c->stash->{rpms}{info} =
        $c->forward('info', [ $c->stash->{pkgid} ]);
    $c->stash->{rpms}{location} =
        $c->forward('location', [ $c->stash->{pkgid} ]);
}

sub rpms : Private {
    my ( $self, $c, $pkgid, $subpart, @args) = @_;
    $c->stash->{rpmurl} = $c->req->path;
    # Because $c->forward don't take into account Chained sub
    $c->forward('rpms_', [ $pkgid ]);
    for ($subpart || '') {
        /^deps$/      and $c->go('alldeps',   [ $pkgid, @args ]);
        /^files$/     and $c->go('files',     [ $pkgid, @args ]);
        /^changelog$/ and $c->go('changelog', [ $pkgid, @args ]);
    }

    return $c->stash->{xmlrpc} = $c->stash->{rpms};
}

sub rpms__ : Chained('/rpms/rpms_') :PathPart('') :Args(0) :XMLRPCLocal {
    my ( $self, $c ) = @_;

    $c->go('rpms', [ $c->stash->{pkgid} ]);
}


sub alldeps :Chained('rpms_') :PathPart('deps') :Args(0) :XMLRPCLocal {
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

sub changelog :Chained('rpms_') :PathPart('changelog') :Args(0) {
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

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
