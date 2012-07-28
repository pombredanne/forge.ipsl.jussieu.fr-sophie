package Sophie::Base::Result::UsersDeps;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('users_dependencies');
__PACKAGE__->add_columns(qw/udkey pid depname evr deptype flags/);
__PACKAGE__->set_primary_key(qw/udkey/);
__PACKAGE__->belongs_to('UsersRpms', 'Sophie::Base::Result::UsersRpms', 'pid');
#__PACKAGE__->has_many(Rpmfile => 'Sophie::Base::Result::RpmFile', 'pkgid');
#__PACKAGE__->has_many(Deps => 'Sophie::Base::Result::Deps', 'pkgid');
#__PACKAGE__->has_many(Files => 'Sophie::Base::Result::Files', 'pkgid');
#__PACKAGE__->has_many(SrcFiles => 'Sophie::Base::Result::SrcFiles', 'pkgid');
#__PACKAGE__->has_many(Tags => 'Sophie::Base::Result::Tags', 'pkgid');

1;
