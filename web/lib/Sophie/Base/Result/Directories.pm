package Sophie::Base::Result::Directories;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('directories');
__PACKAGE__->add_columns(qw/directory parent dir_key/);
__PACKAGE__->set_primary_key(qw/dir_key/);
__PACKAGE__->has_many(BinFiles => 'Sophie::Base::Result::BinFiles', 'dirnamekey');

1;
