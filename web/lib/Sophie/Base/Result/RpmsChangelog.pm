package Sophie::Base::Result::RpmsChangelog;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('rpms');
__PACKAGE__->add_columns(qw/name text time/);
#__PACKAGE__->set_primary_key(qw/pkgid/);
#__PACKAGE__->has_many(Rpmfile => 'Sophie::Base::Result::RpmFile', 'pkgid');
#__PACKAGE__->has_many(Deps => 'Sophie::Base::Result::Deps', 'pkgid');
#__PACKAGE__->has_many(Files => 'Sophie::Base::Result::Files', 'pkgid');
#__PACKAGE__->has_many(Tags => 'Sophie::Base::Result::Tags', 'pkgid');

__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q[
    select 
        rpmquery(header, 'changelogname') as name,
        rpmquery(header, 'changelogtext') as text,
        rpmquery(header, 'changelogtime') as time
    from rpms
    where pkgid = ?
]);


1;
