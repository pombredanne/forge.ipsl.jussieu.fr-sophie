use 5.012002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Sophie-tools',
    VERSION_FROM      => 'lib/Sophie/Client.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (AUTHOR         => 'Olivier Thauvin <nanardon@nanardon.zarb.org>') : ()),
    EXE_FILES => [ qw(
        bin/sophie-rpm
        )],
);