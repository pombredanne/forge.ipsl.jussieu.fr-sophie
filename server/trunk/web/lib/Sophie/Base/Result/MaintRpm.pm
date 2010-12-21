package Sophie::Base::Result::MaintRpm;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('maint_list');
__PACKAGE__->add_columns(qw/sources rpm owner/);
__PACKAGE__->set_primary_key(qw/sources rpm/);
__PACKAGE__->belongs_to(MaintSources => 'Sophie::Base::Result::MaintSources', 'sources');
#__PACKAGE__->has_many(Rpms => 'Sophie::Base::Result::Rpms', 'name');


1;
