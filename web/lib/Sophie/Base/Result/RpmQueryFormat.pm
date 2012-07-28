package Sophie::Base::Result::RpmQueryFormat;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('rpms');
__PACKAGE__->add_columns(qw/qf/);
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q[
    SELECT
        rpmqueryformat("header", ?) AS qf
    FROM rpms
    WHERE ( pkgid = ? )
]);

1;
