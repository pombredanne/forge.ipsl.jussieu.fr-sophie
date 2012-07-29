package Sophie::Controller::Search::Rpms;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Search::Rpms - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Sophie::Controller::Search::Rpms in Search::Rpms.');
}

sub rpms_rs : Private {
    my ( $self, $c, $searchspec) = @_;
    $searchspec ||= {};

    return $c->forward('/distrib/distrib_rs', [ $searchspec ])
        ->search_related('MediasPaths')
        ->search_related('Paths')
        ->search_related('Rpmfile',
            {
                pkgid => {
                    IN => $c->model('Base::Rpms')->search(
                        {
                            (exists($searchspec->{name})
                                ? (name => $searchspec->{name})
                                : ()
                            ),
                            (exists($searchspec->{src})
                                ? (issrc => $searchspec->{src} ? 1 : 0)
                                : ()
                            ),
                        }
                    )->get_column('pkgid')->as_query,
                }
            },
            {
                select => [qw(filename pkgid me.name me.shortname Release.version Arch.arch Medias.label) ],
                as => [qw(filename pkgid distribution dist release arch media) ],
                rows => $searchspec->{rows} || 30000,
                order_by => [ 'Rpmfile.added desc' ],
            },
        );
}

=head2 search.rpms.bydate (SEARCHSPEC, TIMESTAMP)

Return a list of rpms files added since TIMESTAMP.
TIMESTAMP must the number of second since 1970-01-01 (eq UNIX epoch).

SEARCHSPEC is a struct with following key/value:

=over 4

=item distribution

Limit search to this distribution

=item release

Limit search to this release

=item arch

Limit search to distribution of this arch

=item src

If set to true, limit search to source package, If set to false, limit search to
binary package.

=item name

Limit search to rpm having this name

=item rows

Set maximum of results, the default is 10000.

=back

Each elements of the output is a struct:

=over 4

=item filename

the rpm filename

=item pkgid

the identifier of the package

=item distribution

the distribution containing this package

=item release

the release containing this package

=item arch

the arch containing this package

=item media

the media containing this package

=back

=cut

sub bydate : Private {
    my ( $self, $c, $searchspec, $date ) = @_;
    $searchspec ||= {};

    return $c->stash->{xmlrpc} = [
        map {
            { 
            $_->get_columns
            }
        }
        $c->forward('bydate_rpc', [ $searchspec, $date ])->all ];
}

sub bydate_rpc : XMLRPCPath('bydate') {
    my ( $self, $c, $searchspec, $date ) = @_;
    $searchspec ||= {};

    $c->stash->{rs} = $c->forward('rpms_rs')->search(
        \[ "Rpmfile.added > '1970-01-01'::date + ?::interval",
            [ plain_text => "$date seconds" ],
        ]
    );
}

sub byfilename : Private {
    my ( $self, $c, $searchspec, $file ) = @_;
    $searchspec ||= {};

    return $c->stash->{xmlrpc} = [
        map {
            { 
            $_->get_columns
            }
        }
        $c->forward('byfilename_rpc', [ $searchspec, $file ])->all ];
}

sub byfilename_rpc : XMLRPCPath('byfilename') {
    my ( $self, $c, $searchspec, $file ) = @_;
    $searchspec ||= {};

    $c->stash->{rs} =
        $c->forward('rpms_rs', [ $searchspec ])->search(
        {
            filename => { LIKE => $file },
        },
        {
            order_by => [ qw(filename) ],
        }
    );
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
