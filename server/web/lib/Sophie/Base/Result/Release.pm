package Sophie::Base::Result::Release;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('d_release');
__PACKAGE__->add_columns(qw/d_release_key version distributions/);
__PACKAGE__->set_primary_key('d_release_key');
__PACKAGE__->belongs_to(Distribution => 'Sophie::Base::Result::Distribution', 'distributions');
__PACKAGE__->has_many(Arch => 'Sophie::Base::Result::Arch', 'd_release');


1;
