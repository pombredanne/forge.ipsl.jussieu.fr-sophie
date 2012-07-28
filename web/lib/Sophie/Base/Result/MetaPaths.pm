package Sophie::Base::Result::MetaPaths;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('d_meta_path');
__PACKAGE__->add_columns(qw/d_meta_path_key path added updated d_arch type data/);
__PACKAGE__->set_primary_key('d_meta_path_key');
__PACKAGE__->belongs_to(Archs => 'Sophie::Base::Result::Arch', 'd_arch');
__PACKAGE__->has_many(Paths => 'Sophie::Base::Result::Paths', 'meta_path');
__PACKAGE__->add_unique_constraint('upath' => [ 'd_arch', 'path', 'type' ]);

1;
