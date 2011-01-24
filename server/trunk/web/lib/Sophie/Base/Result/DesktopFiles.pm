package Sophie::Base::Result::DesktopFiles;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('desktop_file');
__PACKAGE__->add_columns(qw/pkgid count desktop_file_pkey/);
__PACKAGE__->set_primary_key(qw/desktop_file_pkey/);
__PACKAGE__->belongs_to(BinFiles => 'Sophie::Base::Result::BinFiles', [ 'pkgid', 'count' ]);
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');
__PACKAGE__->has_many(DesktopEntries => 'Sophie::Base::Result::DesktopEntries', 'desktop_file');

1;
