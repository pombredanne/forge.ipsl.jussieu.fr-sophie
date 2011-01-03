package Sophie::Controller::0Explorer;
use Moose;
use namespace::autoclean;
use DBD::Pg qw(:async);
use Sophie::Base::Async;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::0Explorer - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub dir :Local {
    my ( $self, $c, @args ) = @_;
    my $dir = join('/', map { "$_" } grep { $_ } @args);
    $c->stash->{path} = $dir;
    $c->stash->{explorerurl} = '/explorer' . ($dir ? "/$dir" : '');

    my $rsdist = $c->forward('/search/distrib_search', [
            $c->session->{__explorer}, 1 ]);
    my %uniq;

    my $query = Sophie::Base::Async->new(
        $c->model('Base'),
        timeout => 30,
        build => sub { $_[0]
            ->resultset('Files')
            ->search(
                {
                    dirname => '/' . ($dir ? "$dir/" : ''),
                    ($rsdist 
                        ? (pkgid => { IN => $rsdist->get_column('pkgid')->as_query, },)
                        : ()),
                    ($c->req->param('filename')
                        ? ( basename => { LIKE => $c->req->param('filename') . '%' } )
                        : ()),
                },
                {
                    #order_by => [ 'basename' ],
                    #group_by => [ 'basename' ], 
                    select => [ 'basename' ],
                }
            )
            ->get_column('basename')
        },
    );

    if(my $sth = $query->wait_result) {
        while (my $res = $sth->fetchrow_hashref()) {
            $uniq{$res->{basename}} = 1;
        }
    } else {
        $c->stash->{timeout} = 1;
    }

    $c->stash->{xmlrpc} = [ sort keys %uniq ]; 
}

sub file :Local {
    my ( $self, $c, @args ) = @_;
    my $basename = pop(@args);
    my $dir = join('/', map { "$_" } grep { $_ } @args);
    $c->stash->{path} = $dir;
    $c->stash->{explorerurl} = '/explorer' . ($dir ? "/$dir" : '');

    my $rsdist = $c->forward('/search/distrib_search', [
            $c->session->{__explorer}, 1 ]);

    my @col = qw(dirname basename md5 size pkgid count);
    $c->stash->{xmlrpc} = [ 
        map { {
                $_->get_columns
            } }
        $c->model('Base')
      ->resultset('Files')
      ->search({
              dirname => '/' . ($dir ? "$dir/" : ''), basename => $basename,
              ($rsdist 
                ? (pkgid => { IN => $rsdist->get_column('pkgid')->as_query, },)
                : ())
          },
          { 
              'select' => [ 'contents is NOT NULL as has_content', 'rpmfilesmode(mode) as perm', @col, '"group"',
                  '"user"' ],
              as => [ qw(has_content perm), @col, 'group', 'user' ],
              order_by => [ 'pkgid' ],

          },
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
