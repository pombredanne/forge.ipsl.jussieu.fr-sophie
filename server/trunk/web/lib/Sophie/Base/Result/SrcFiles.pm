package Sophie::Base::Result::SrcFiles;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('srcfiles');
__PACKAGE__->add_columns(qw/pkgid count basename md5 user group linkto
    mode fflags size class color vflags mtime nlink has_content contents/);
__PACKAGE__->set_primary_key(qw/pkgid count/);
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');


1;
