package Sophie::Controller::Rpms;
use Moose;
use namespace::autoclean;
use Encode::Guess;
use Encode;

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
    my ($self, $c, $pkgid, $deptype) = @_;

    my %info;
    foreach (qw(name version release epoch url group size packager
                url summary description sourcerpm license buildhost
                pkgid builddate arch distribution)) {
        if (my $r = $c->model('base')->resultset('Rpms')->search(
            { pkgid => $pkgid },
            { 
                select => [ qq{rpmqueryformat("header", ?)} ],
                as => [ 'qf' ],
                bind => [ "%{$_}" ],
            }
            )->next) { 
            $info{$_} = $r->get_column('qf');
        }
    }

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

sub alldeps : XMLRPCLocal {
    my ($self, $c, $pkgid) = @_;

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

sub files : XMLRPCLocal {
    my ($self, $c, $pkgid) = @_;

    $c->stash->{xmlrpc} = [ map {
        {
            filename => $_->get_column('dirname') . $_->get_column('basename'),
            md5 => $_->get_column('md5'),
        }
    } $c->model('Base')->resultset('Files')->search(
            { 
                pkgid => $pkgid,
            },
            { 
                order_by => [ 'count' ],

            },
        )->all ];
}

sub changelog : XMLRPCLocal {
    my ($self, $c, $pkgid) = @_;

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
        push(@ch, $chentry);
    }

    $c->stash->{xmlrpc} = \@ch;
}


sub rpms : Chained : PathPart :XMLRPCLocal {
    my ( $self, $c, $pkgid ) = @_;
    $c->stash->{pkgid} = $c->model('Base')->resultset('Rpms')->search(pkgid => $pkgid)->next;
    $c->stash->{xmlrpc} = {
        info      => $c->forward('info', [ $pkgid ]),
        changelog => $c->forward('changelog', [ $pkgid ]),
        files     => $c->forward('files', [ $pkgid ]),
        deps      => $c->forward('alldeps', [ $pkgid ]),
    };
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
