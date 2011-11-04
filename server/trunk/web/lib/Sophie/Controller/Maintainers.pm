package Sophie::Controller::Maintainers;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Maintainers - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 maintainers.byrpm ( RPMNAME, [ DISTRIB ] )

Return the list of maintainers for rpm source name C<RPMNAME>.

The optional C<DISTRIB> filter the result to this specific distribution.

Result example:

    [
        {
            'owner' => 'rpmmaintainer',
            'distribution' => 'Mandriva'
            'vendor' => 'Mandriva'
        }
    ];

=head2 Url: /maintainers/<RPM>/<DISTRIB>

Return the list of maintainers for source rpm named C<RPM> for distribution
C<DISTRIB>.

Theses alternatives are supported:

    /maintainers?rpm=<RPM>;distrib=<DISTRIB>

    /maintainers/rpm?distrib=<DISTRIB>

=cut

sub byrpm :Path :XMLRPC {
    my ($self, $c, $rpm, $distrib) = @_;
    $rpm     ||= $c->req->param('rpm');
    $distrib ||= $c->req->param('distrib');

    $c->stash->{xmlrpc} = [ map { { $_->get_columns } } 
    $c->model('Base::MaintRpm')->
        search(
            { rpm => $rpm },
            { select => [ qw(owner) ] },
        )->
        search_related('MaintSources')->
        search_related('MaintDistrib')->
        search_related('Distribution',
            $distrib ? {
                '-or' => [
                    { shortname => $distrib },
                    { name => $distrib },
                ],
            } : (),
        )->search({},
            {
                'select' => [ qw'me.owner name maintsources.label' ],
                'as'     => [ qw'owner distribution vendor' ],
            }
        )->all ];
}

=head2 maintainers.bymaintainer ( MAINT, [ DISTRIB ] )

Return the list of rpms for maintainer C<MAINT>.

The optional C<DISTRIB> filter the result to this specific distribution.

Result example:

    [
        {
            'rpm' => 'rpm package',
            'distribution' => 'Mandriva'
            'vendor' => 'Mandriva'
        }
    ];

=cut


sub bymaintainer : XMLRPC {
    my ($self, $c, $maint, $distrib) = @_;
    $c->stash->{xmlrpc} = [ map { { $_->get_columns } } 
    $c->model('Base::MaintRpm')->
        search(
            { owner => $maint },
            { select => [ qw(rpm) ] },
        )->
        search_related('MaintSources')->
        search_related('MaintDistrib')->
        search_related('Distribution',
            $distrib ? {
                '-or' => [
                    { shortname => $distrib },
                    { name => $distrib },
                ],
            } : (),
        )->search({},
            {
                'select' => [ qw'rpm name label' ],
                'as'     => [ qw'rpm distribution vendor' ],
            }
        )->all ];
    
}

=head2 maintainers.search ( MAINT, [ DISTRIB ] )

Search the database for a maintainer matching C<MAINT>.

The optional C<DISTRIB> filter the result to this specific distribution.

Result example:

    [
        {
            'owner' => 'maintainer',
            'distribution' => 'Mandriva'
            'vendor' => 'Mandriva'
        }
    ];

=cut

sub search :XMLRPC {
    my ($self, $c, $maint, $distrib) = @_;

    $c->stash->{xmlrpc} = [ map { { $_->get_columns } }
        $c->model('Base::MaintRpm')->search(
            { owner => { 'LIKE' => "%$maint%" } }
        )->search_related('MaintSources'
        )->search_related('MaintDistrib'
        )->search_related('Distribution',
            $distrib ? {
                '-or' => [
                    { shortname => $distrib },
                    { name => $distrib },
                ],
            } : (),
        )->search({},
            {
                'select' => [ qw'owner name label' ],
                'as'     => [ qw'owner distribution vendor' ],
                'group_by' => [ qw'owner name label' ],
                'order_by' => [ qw'owner name label' ],
            }
        )->all ];
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
