package Sophie::Base::Result::IndexedTags;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('index_tag');
__PACKAGE__->add_columns(qw/tagname/);
__PACKAGE__->set_primary_key(qw/tagname/);
__PACKAGE__->has_many(Tags => 'Sophie::Base::Result::Tags', 'tagname');

1;
