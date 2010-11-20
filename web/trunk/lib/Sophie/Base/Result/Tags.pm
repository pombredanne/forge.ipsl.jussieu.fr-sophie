package Sophie::Base::Result::Tags;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('rpms_tags');
__PACKAGE__->add_columns(qw/pkgid tagname value/);
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');


1;
