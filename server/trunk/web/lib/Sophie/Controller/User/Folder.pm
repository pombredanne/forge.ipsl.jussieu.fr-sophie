package Sophie::Controller::User::Folder;
use Moose;
use namespace::autoclean;
use XML::Simple;
use MIME::Base64;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::User::Folder - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::User::folder in User::folder.');
}

sub list :XMLRPC :Local {
    my ($self, $c ) = @_;

    $c->stash->{xmlrpc} = [
        map { { $_->get_columns } }
        $c->model('Base::UsersRpms')->search(
        {
            ($c->user_exists
            ? ( user_fkey => $c->model('Base::Users')->find({ mail =>
                        $c->user->mail })->ukey )
            : ( sessions_fkey => 'session:' . $c->sessionid ) ),
        }
    )->all ]
}

sub delete :XMLRPC :Local {
    my ($self, $c, $pid ) = @_;
    $pid ||= $c->req->param('delete');

    my $pkg = $c->model('Base::UsersRpms')->search(
        {
            -and => [ {
            ($c->user_exists
            ? ( user_fkey => $c->model('Base::Users')->find({ mail =>
                        $c->user->mail })->ukey )
            : ( sessions_fkey => 'session:' . $c->sessionid ) ),
            },
            { id => $pid },
            ]
        }
    )->first;
    if ($pkg) {
        $pkg->delete;
        $c->model('Base')->storage->dbh->commit;
        $c->stash->{xmlrpc} = 'Delete';
    } else {
        $c->stash->{xmlrpc} = 'No package found';
    }
}

sub clear : XMLRPC : Local {
    my ($self, $c, $pid ) = @_;
    $pid ||= $c->req->param('delete');

    my $pkg = $c->model('Base::UsersRpms')->search(
        {
            -and => [ {
            ($c->user_exists
            ? ( user_fkey => $c->model('Base::Users')->find({ mail =>
                        $c->user->mail })->ukey )
            : ( sessions_fkey => 'session:' . $c->sessionid ) ),
            },
            ]
        }
    )->delete;
    $c->model('Base')->storage->dbh->commit;
    $c->stash->{xmlrpc} = 'Empty';
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

sub bydep : XMLRPCLocal {
    my ($self, $c, $pool, $deptype, $depname, $sense, $evr) = @_;

    $c->stash->{xmlrpc} = [ $c->model('Base::UsersRpms')->search(
        {
            -and => [
                { id => $pool, },
                { 
                    id => {
                        IN => $c->model('Base::UsersDeps')->search({
                            deptype => $deptype,
                            depname => $depname,
                            ( $evr
                                ?  (-nest => \[
                                    "rpmdepmatch(flags, evr, rpmsenseflag(?), ?)",
                                    [ plain_text => $sense],
                                    [ plain_text => $evr ],
                                ])
                            : ()),
                        })->get_column('pid')->as_query,
                    }
                },
            ],
        }
    )->get_column('id')->all ];
}

sub byfile : XMLRPCLocal {
    my ($self, $c, $pool, $file) = @_;
    my ($dirname, $basename) = $file =~ m:^(.*/)?([^/]+)$:;


    $c->stash->{xmlrpc} = [ $c->model('Base::UsersRpms')->search(
        {
            -and => [
                { id => $pool, },
                { 
                    id => {
                        IN => $c->model('Base::UsersFiles')->search({
                                ($dirname
                                    ? (dirname => $dirname)
                                    : ()),
                                basename => $basename,
                        })->get_column('pid')->as_query,
                    }
                },
            ],
        }
    )->get_column('id')->all ];
}


=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

