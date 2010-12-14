package Sophie::Controller::Analysis;
use Moose;
use namespace::autoclean;
use XML::Simple;
use MIME::Base64;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Analysis - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Analysis in Analysis.');
}

sub load_rpm : XMLRPCLocal {
    my ($self, $c, $string) = @_;

    my $ref = XMLin($string, ForceArray => 1);
    my $tags = $ref->{rpmTag} or return;


    my $User = $c->user
        ? $c->model('Base')->resultset('Users')->find( { mail => $c->user->mail } )
        : undef;
    $c->session;
    $c->store_session_data('session:' . $c->sessionid, $c->session);

    my $pkgid = unpack('H*',MIME::Base64::decode($tags->{Sigmd5}{base64}[0]));

    my $newrpm = $c->model('Base::UsersRpms')->create(
        {
            name => $tags->{Name}{string}[0],
            evr => sprintf('%s%s-%s',
                defined($tags->{Epoch}{integer}[0]) ?
                $tags->{Epoch}{integer}[0] . ':' : '',
                $tags->{Version}{string}[0],
                $tags->{Release}{string}[0],
            ),
            user_fkey => $User,
            sessions_fkey => 'session:' . $c->sessionid,
            pkgid => $pkgid,
        }
    );
    {
        my @populate;
        foreach my $fcount (0 .. $#{$tags->{Basenames}{string}}) {
            push(@populate,
                {
                    pid => $newrpm->id,
                    basename => $tags->{Basenames}{string}[$fcount],
                    dirname  => $tags->{Dirnames}{string}[
                        $tags->{Dirindexes}{integer}[$fcount]
                    ],
                }
            );
        }
        $c->model('Base::UsersFiles')->populate(\@populate) if(@populate);
    }
    {
        my @populate;
        foreach my $dtype (qw(Provide Require Conflict Obsolete Suggest Enhanced)) {
            my $initial = substr($dtype, 0, 1);
            $tags->{"${dtype}name"} or next;
            foreach my $fcount (0 .. $#{$tags->{"${dtype}name"}{string}}) {
                push(@populate,
                    {
                        pid => $newrpm->id,
                        deptype => $initial,
                        depname => $tags->{"${dtype}name"}{string}[$fcount],
                        evr => ref $tags->{"${dtype}version"}{string}[$fcount]
                        ? ''
                        : $tags->{"${dtype}version"}{string}[$fcount],
                        flags => $tags->{"${dtype}flags"}{integer}[$fcount] || 0,
                    }
                );
            }
        }
        $c->model('Base::UsersDeps')->populate(\@populate) if(@populate);
    }
    $c->model('Base')->storage->dbh->commit;

    $c->stash->{xmlrpc} = $newrpm->id;
}

sub find_requirements : XMLRPC {
    my ($self, $c, $string) = @_;

    my $id = $c->forward('load_rpm', [ $string ]);

    my @deplist;
    foreach my $dep ($c->model('Base::UsersDeps')->search(
        {
            pid => [ $id ],
            deptype => 'R',
        },
        {
            select => [ 'rpmsenseflag("flags")',
                qw(depname flags evr deptype) ],
            as => [ qw'sense depname flags evr deptype' ],
        }
        )->all) {
        $dep->get_column('depname') =~ /^rpmlib\(/ and next;
        push(@deplist, [
                $dep->get_column('depname'),
                $dep->get_column('sense'),
                $dep->get_column('evr') ]);
    }

    $c->forward('/analysis/solver/find_requirements', [ {}, 'P', \@deplist ]);
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
