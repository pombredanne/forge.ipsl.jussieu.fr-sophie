package Sophie::View::Json;

use strict;
use base 'Catalyst::View::JSON';

__PACKAGE__->config(expose_stash => [ qw(xmlrpc) ]);

=head1 NAME

Sophie::View::Json - Catalyst JSON View

=head1 SYNOPSIS

See L<Sophie>

=head1 DESCRIPTION

Catalyst JSON View.

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
