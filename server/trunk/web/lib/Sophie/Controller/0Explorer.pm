package Sophie::Controller::0Explorer;
use Moose;
use namespace::autoclean;

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

    my $rsdist = $c->forward('/search/distrib_search', [ $c->session->{__explorer} ]);
    $c->stash->{xmlrpc} = [ $c->model('Base')
      ->resultset('Files')
      ->search(
          {
              dirname => '/' . ($dir ? "$dir/" : ''),
              pkgid => { IN => $rsdist->get_column('pkgid')->as_query, },
          },
          {
              order_by => [ 'basename' ],
              group_by => [ 'basename' ], 
              select => [ 'basename' ],
          }
      )->get_column('basename')->all ];
}

sub file :Local {
    my ( $self, $c, @args ) = @_;
    my $basename = pop(@args);
    my $dir = join('/', map { "$_" } grep { $_ } @args);
    $c->stash->{path} = $dir;
    $c->stash->{explorerurl} = '/explorer' . ($dir ? "/$dir" : '');

    my $rsdist = $c->forward('/search/distrib_search', [ $c->session->{__explorer} ]);

    my @col = qw(dirname basename md5 size pkgid count);
    $c->stash->{xmlrpc} = [ 
        map { {
            pkgid => $_->get_column('pkgid'),
            filename => $_->get_column('dirname') . $_->get_column('basename'),
            dirname => $_->get_column('dirname'),
            basename => $_->get_column('basename'),
            md5 => $_->get_column('md5'),
            perm => $_->get_column('perm'),
            size => $_->get_column('size'),
            user => $_->get_column('user'),
            group => $_->get_column('group'),
            has_content => $_->get_column('has_content'),
            count => $_->get_column('count')
            } }
        $c->model('Base')
      ->resultset('Files')
      ->search({
              dirname => '/' . ($dir ? "$dir/" : ''), basename => $basename,
              pkgid => { IN => $rsdist->get_column('pkgid')->as_query, },
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
