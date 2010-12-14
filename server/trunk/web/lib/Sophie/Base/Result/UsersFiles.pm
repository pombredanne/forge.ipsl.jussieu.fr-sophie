package Sophie::Base::Result::UsersFiles;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('users_files');
__PACKAGE__->add_columns(qw/ufkey pid basename dirname/);
__PACKAGE__->set_primary_key(qw/ufkey/);
__PACKAGE__->belongs_to('UsersRpms', 'Sophie::Base::Result::UsersRpms', 'pid');

1;
