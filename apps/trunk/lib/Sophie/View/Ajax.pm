package Sophie::View::Ajax;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
    __PACKAGE__->config(
        TEMPLATE_EXTENSION => '.tt',
        render_die => 1,
        INCLUDE_PATH => [
            Sophie->path_to( 'root', 'templates', 'ajax' ),
        ],
    )
);

=head1 NAME

Sophie::View::Ajax - TT View for Sophie

=head1 DESCRIPTION

TT View for Sophie.

=head1 SEE ALSO

L<Sophie>

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
