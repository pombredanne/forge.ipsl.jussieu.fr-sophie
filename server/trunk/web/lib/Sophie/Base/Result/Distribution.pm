package Sophie::Base::Result::Distribution;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('distributions');
__PACKAGE__->add_columns(qw/distributions_key name shortname/);
__PACKAGE__->set_primary_key('distributions_key');
__PACKAGE__->has_many(Release => 'Sophie::Base::Result::Release', 'distributions');

1;
