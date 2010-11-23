#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'Sophie';
all_from 'lib/Sophie.pm';

requires 'Catalyst::Runtime' => '5.80025';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Catalyst::Plugin::Authentication' => '0';
requires 'Catalyst::Plugin::Session' => '0';
requires 'Catalyst::Plugin::Session::Store::DBI' => '0';
requires 'Catalyst::Plugin::Session::State::Cookie' => '0';
requires 'Catalyst::Plugin::Prototype' => '0';
requires 'Catalyst::View::TT' => '0';
requires 'DBD::Pg';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');

WriteMakefile(
    macro => { 
        DESTRPMDIR => '$(shell pwd)',
    },
);

package MY;

sub postamble {
    <<EOF;
# .PHONY .= svnmanifest

svnmanifest:
\tsvn ls -R| grep -v "/\$\$"  > MANIFEST

ChangeLog:
\tsvn log > ChangeLog

\$(DISTNAME).spec: \$(DISTNAME).spec.in Makefile
\tsed -e 's/\@VERSION@/\$(VERSION)/' < \$< > \$@

rpm: \$(DISTVNAME).tar.gz \$(DISTNAME).spec
\tmkdir \$(DESTRPMDIR)/noarch || :
\trpmbuild -ba --clean\\
\t --define "_sourcedir `pwd`" \\
\t --define "_specdir `pwd`" \\
\t --define "_srcrpmdir \$(DESTRPMDIR)" \\
\t --define "_rpmdir \$(DESTRPMDIR)" \\
\t \$(DISTNAME).spec

svnrpm: \$(DISTVNAME).tar.gz \$(DISTNAME).spec
\tmkdir \$(DESTRPMDIR)/noarch || :
\trpmbuild -ba --clean\\
\t --define "_sourcedir `pwd`" \\
\t --define "_specdir `pwd`" \\
\t --define "_srcrpmdir \$(DESTRPMDIR)" \\
\t --define "_rpmdir \$(DESTRPMDIR)" \\
\t --define "svnrelease `LC_ALL=C svn info | grep '^Revision:' | sed 's/Revision: //'`" \\
\t \$(DISTNAME).spec

EOF
}
