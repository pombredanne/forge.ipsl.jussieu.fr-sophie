package Sophie::Base::Result::MediasPaths;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('d_media_path');
__PACKAGE__->add_columns(qw/d_media d_path/);
__PACKAGE__->set_primary_key(qw/d_media d_path/);
__PACKAGE__->belongs_to(Medias => 'Sophie::Base::Result::Medias', 'd_media');
__PACKAGE__->belongs_to(Paths => 'Sophie::Base::Result::Paths', 'd_path');
__PACKAGE__->add_relationship( RpmFiles => 'Sophie::Base::Result::RpmFile',
                             { 'foreign.d_path' => 'self.d_path' });


1;
