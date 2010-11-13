package Sophie::Base::Result::Rpms;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('rpms');
__PACKAGE__->add_columns(qw/pkgid summary description issrc/);
__PACKAGE__->set_primary_key(qw/pkgid/);
__PACKAGE__->has_many(Rpmfile => 'Sophie::Base::Result::RpmFile', 'pkgid');
__PACKAGE__->has_many(Deps => 'Sophie::Base::Result::Deps', 'pkgid');
__PACKAGE__->has_many(Files => 'Sophie::Base::Result::Files', 'pkgid');
__PACKAGE__->has_many(Tags => 'Sophie::Base::Result::Tags', 'pkgid');

1;
