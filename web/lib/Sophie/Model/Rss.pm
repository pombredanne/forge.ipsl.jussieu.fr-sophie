package Sophie::Model::Rss;
use Moose;
use namespace::autoclean;
use POSIX qw(strftime);

extends 'Catalyst::Model';
extends 'XML::RSS';

=head1 NAME

Sophie::Model::Rss - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

sub new {
    my ($class) = @_;

    bless({}, $class);
}

sub ACCEPT_CONTEXT {
    my ($self, $c, %options) = @_;

    my $new =  bless(XML::RSS->new(version => '2.0'), __PACKAGE__);
    $new->channel(
        title          => 'Sophie rpms girafe',
        link           => $c->uri_for('/'),
        language       => 'en',
        description    => "Sophie's Feed",
        rating
            => '(PICS-1.1 "http://www.classify.org/safesurf/" 1 r (SS~~000 1))',
        copyright      => 'Copyright 2010, Nanar',
        pubDate        => strftime('%a, %d  %b  %Y %H:%M:%S %z', gmtime()),
        lastBuildDate  => strftime('%a, %d  %b  %Y %H:%M:%S %z', gmtime()),
        docs           => 'http://sophie.zarb.org/trac',
        managingEditor => 'nanardon@nanardon.zarb.org',
        webMaster      => 'nanardon@nanardon.zarb.org',
    );

    return $new;
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
