package Sophie::Base::Result::ChatStat;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('chat_stat');
__PACKAGE__->add_columns(qw/cmd day count/);
__PACKAGE__->set_primary_key('cmd', 'day');

1;
