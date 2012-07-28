package Sophie::Base::Result::UsersData;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('users_data');
__PACKAGE__->add_columns(qw/users_fkey varname value/);
__PACKAGE__->set_primary_key('users_fkey', 'varname');
__PACKAGE__->belongs_to(Users => 'Sophie::Base::Result::Users', 'users_fkey');

1;
