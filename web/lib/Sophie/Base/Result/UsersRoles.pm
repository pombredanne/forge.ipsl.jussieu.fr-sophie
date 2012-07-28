package Sophie::Base::Result::UsersRoles;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('users_roles');
__PACKAGE__->add_columns(qw/users_fkey rolename/);
__PACKAGE__->set_primary_key('users_fkey', 'rolename');
__PACKAGE__->belongs_to(Users => 'Sophie::Base::Result::Users', 'users_fkey');

1;
