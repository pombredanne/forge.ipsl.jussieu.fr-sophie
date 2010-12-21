package Sophie::Base::Result::MaintSources;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('maint_sources');
__PACKAGE__->add_columns(qw/pkey url label accessor/);
__PACKAGE__->set_primary_key('pkey');
#__PACKAGE__->belongs_to(Distribution => 'Sophie::Base::Result::Distribution', 'distributions');
__PACKAGE__->has_many(MaintRpm => 'Sophie::Base::Result::MaintRpm', 'sources');
__PACKAGE__->has_many(MaintDistrib => 'Sophie::Base::Result::MaintDistrib', 'sources');


1;
