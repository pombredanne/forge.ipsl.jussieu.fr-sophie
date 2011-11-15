package Sophie::Base::Result::Paths;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('d_path');
__PACKAGE__->add_columns(
    qw/d_path_key path added updated meta_path
    exists needupdate/
);
__PACKAGE__->set_primary_key('d_path_key');
__PACKAGE__->add_unique_constraint('path' => [ 'path' ]);
__PACKAGE__->belongs_to('MetaPaths' => 'Sophie::Base::Result::MetaPaths', 'meta_path');
__PACKAGE__->has_many(MediasPaths => 'Sophie::Base::Result::MediasPaths', 'd_path');
__PACKAGE__->has_many(Rpmfiles => 'Sophie::Base::Result::RpmFile', 'd_path');


1;
