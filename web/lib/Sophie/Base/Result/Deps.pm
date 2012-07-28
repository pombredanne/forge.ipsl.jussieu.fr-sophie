package Sophie::Base::Result::Deps;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('dependencies');
__PACKAGE__->add_columns(qw/pkgid deptype count depname pkgid flags evr color/);
__PACKAGE__->set_primary_key(qw/pkgid deptype count/);
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');

__PACKAGE__->add_relationship( RpmFile => 'Sophie::Base::Result::RpmFile',
                             { 'foreign.pkgid' => 'self.pkgid' });
1;
