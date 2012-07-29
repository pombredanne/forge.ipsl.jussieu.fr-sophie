package Sophie::View::Email;

use strict;
use base 'Catalyst::View::Email';

__PACKAGE__->config(
    stash_key => 'email'
);

=head1 NAME

Sophie::View::Email - Email View for Sophie

=head1 DESCRIPTION

View for sending email from Sophie. 

=head1 AUTHOR

olivier

=head1 SEE ALSO

L<Sophie>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
