package Sophie::Base::Result::MaintDistrib;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('maint_distrib');
__PACKAGE__->add_columns(qw/sources distributions_key/);
__PACKAGE__->set_primary_key(qw/sources distributions_key/);
__PACKAGE__->belongs_to(MaintSources => 'Sophie::Base::Result::MaintSources', 'sources');
__PACKAGE__->belongs_to(Distribution => 'Sophie::Base::Result::Distribution', 'distributions_key');
#__PACKAGE__->has_many(Arch => 'Sophie::Base::Result::Arch', 'd_release');


1;
