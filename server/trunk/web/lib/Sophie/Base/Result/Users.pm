package Sophie::Base::Result::Users;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('users');
__PACKAGE__->add_columns(qw/ukey mail password/);
__PACKAGE__->set_primary_key('ukey');
__PACKAGE__->has_many(Roles => 'Sophie::Base::Result::UsersRoles', 'users_fkey');
__PACKAGE__->has_many(UsersData => 'Sophie::Base::Result::UsersData', 'users_fkey');

1;
