package Sophie::Base::Result::Arch;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('d_arch');
__PACKAGE__->add_columns(qw/d_arch_key arch d_release/);
__PACKAGE__->set_primary_key('d_arch_key');
__PACKAGE__->belongs_to(Release => 'Sophie::Base::Result::Release', 'd_release');
__PACKAGE__->has_many(Medias => 'Sophie::Base::Result::Medias', 'd_arch');
__PACKAGE__->has_many(MetaPaths => 'Sophie::Base::Result::MetaPaths', 'd_arch');

1;
