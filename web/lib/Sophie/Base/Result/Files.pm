package Sophie::Base::Result::Files;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('files');
__PACKAGE__->add_columns(qw/pkgid count dirname basename md5 user group linkto
    mode fflags size class color vflags mtime nlink has_content/);
__PACKAGE__->set_primary_key(qw/pkgid count/);
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');

__PACKAGE__->add_relationship( RpmFile => 'Sophie::Base::Result::RpmFile',
                             { 'foreign.pkgid' => 'self.pkgid' });


1;
