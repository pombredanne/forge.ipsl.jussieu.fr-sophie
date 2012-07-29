package Sophie::Base::Result::RpmFile;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('rpmfiles');
__PACKAGE__->add_columns(qw/d_path filename pkgid added mtime size/);
__PACKAGE__->set_primary_key(qw/d_path filename/);
__PACKAGE__->belongs_to(Paths => 'Sophie::Base::Result::Paths', 'd_path');
__PACKAGE__->belongs_to(Rpms => 'Sophie::Base::Result::Rpms', 'pkgid');

__PACKAGE__->add_relationship(  MediasPaths => 'Sophie::Base::Result::MediasPaths',
                              { 'foreign.d_path' => 'self.d_path' });

__PACKAGE__->add_relationship(  Deps => 'Sophie::Base::Result::Deps',
                              { 'foreign.pkgid' => 'self.pkgid' });
__PACKAGE__->add_relationship(  Files => 'Sophie::Base::Result::Files',
                              { 'foreign.pkgid' => 'self.pkgid' });
__PACKAGE__->add_relationship(  BinFiles => 'Sophie::Base::Result::BinFiles',
                              { 'foreign.pkgid' => 'self.pkgid' });
__PACKAGE__->add_relationship(  SrcFiles => 'Sophie::Base::Result::SrcFiles',
                              { 'foreign.pkgid' => 'self.pkgid' });
__PACKAGE__->add_relationship(  Tags => 'Sophie::Base::Result::Tags',
                              { 'foreign.pkgid' => 'self.pkgid' });

__PACKAGE__->add_relationship(  DesktopFiles => 'Sophie::Base::Result::DesktopFiles',
                              { 'foreign.pkgid' => 'self.pkgid' });

1;
