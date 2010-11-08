package Sophie::Base::Result::Medias;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('d_media');
__PACKAGE__->add_columns(qw/d_media_key label comment group_label d_arch/);
__PACKAGE__->set_primary_key('d_media_key');
__PACKAGE__->belongs_to(Arch => 'Sophie::Base::Result::Arch', 'd_arch');
__PACKAGE__->has_many(MediasPaths => 'Sophie::Base::Result::MediasPaths', 'd_media');

1;
