use 5.012002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Sophie::Tools',
    VERSION_FROM      => 'lib/Sophie/Bot.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Sophie/Bot.pm', # retrieve abstract from module
       AUTHOR         => 'Olivier Thauvin <nanardon@nanardon.zarb.org>') : ()),
    EXE_FILES => [ qw(
        bin/sophie-bot
        bin/sophie-rpm
    ) ],
    macro => {
        INSTALLMAN5DIR      => '$(PERLPREFIX)/share/man/man5',
        DESTINSTALLMAN5DIR  => '$(DESTDIR)$(INSTALLMAN5DIR)',
        INST_MAN5DIR        => 'blib/man5',
        DESTRPMDIR          => '$(shell pwd)'
    },
);

package MY;

sub postamble {
    <<EOF;
#.PHONY .= svnmanifest

svnmanifest:
\tsvn ls -R| grep -v "/\$\$"  > MANIFEST

ChangeLog:
\tsvn log > ChangeLog

sophie-tools.spec: sophie-tools.spec.in Makefile
\tsed -e 's/\@VERSION@/\$(VERSION)/' < \$< > \$@

rpm: \$(DISTVNAME).tar.gz sophie-tools.spec
\tmkdir ./noarch || :
\trpmbuild -ba --clean\\
\t --define "_sourcedir `pwd`" \\
\t --define "_specdir `pwd`" \\
\t --define "_srcrpmdir \$(DESTRPMDIR)" \\
\t --define "_rpmdir \$(DESTRPMDIR)" \\
\t sophie-tools.spec

svnrpm: \$(DISTVNAME).tar.gz sophie-tools.spec
\tmkdir \$(DESTRPMDIR)/noarch || :
\trpmbuild -ba --clean\\
\t --define "_sourcedir `pwd`" \\
\t --define "_specdir `pwd`" \\
\t --define "_srcrpmdir \$(DESTRPMDIR)" \\
\t --define "_rpmdir \$(DESTRPMDIR)" \\
\t --define "svnrelease `LC_ALL=C svn info | grep '^Revision:' | sed 's/Revision: //'`" \\
\t sophie-tools.spec

EOF
}

sub installbin {
    my $self = shift;
    my $inherited = $self->SUPER::installbin(@_);
    $inherited;
}

sub top_targets {
    my $inherited = shift->SUPER::top_targets(@_);
    $inherited;
}

sub install {
    my ($self) = @_;
    my $section = $self->SUPER::install();

    $section =~ s/(^install ::.*)/$1 install_config install_templates/m;

    $section .= q[
install_config ::

install_templates ::
];
  
    return $section;
}
