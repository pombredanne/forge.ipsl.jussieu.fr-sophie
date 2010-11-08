package Sophie::Base::Result::Deps;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('dependencies');
__PACKAGE__->add_columns(qw/pkgid deptype count name pkgid/);
__PACKAGE__->set_primary_key(qw/pkgid deptype count/);
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');


1;
