package Sophie::Base::Result::RpmFile;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('rpmfiles');
__PACKAGE__->add_columns(qw/d_path filename pkgid added/);
__PACKAGE__->set_primary_key(qw/d_path filename/);
__PACKAGE__->belongs_to(Path => 'Sophie::Base::Result::Paths', 'd_path');
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');
#__PACKAGE__->has_many(mediaspaths => 'Sophie::Base::Result::MediasPaths', 'path');


1;
