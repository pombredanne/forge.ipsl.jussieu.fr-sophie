package Sophie::Base::Result::ChatPaste;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('chat_paste');
__PACKAGE__->add_columns(qw/user_id id reply whenpaste title/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(Users => 'Sophie::Base::Result::Users', 'user_id');

1;
