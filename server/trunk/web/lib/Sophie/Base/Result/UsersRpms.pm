package Sophie::Base::Result::UsersRpms;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('users_rpms');
__PACKAGE__->add_columns(qw/id name evr user_fkey sessions_fkey pkgid issrc/);
__PACKAGE__->set_primary_key(qw/id/);
__PACKAGE__->has_many(UsersFiles => 'Sophie::Base::Result::UsersFiles', 'pid');
__PACKAGE__->has_many(UsersDeps => 'Sophie::Base::Result::UsersDeps', 'pid');

1;
