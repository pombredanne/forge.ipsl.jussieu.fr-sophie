package Sophie::Base::Result::DesktopEntries;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('desktop_entry');
__PACKAGE__->add_columns(qw/desktop_file key locale value/);
__PACKAGE__->set_primary_key(qw/desktop_file key locale/);
__PACKAGE__->belongs_to(DesktopFiles => 'Sophie::Base::Result::DesktopFiles', 'desktop_file');

1;
