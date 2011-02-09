package Sophie::Scan::RpmParser::Config;

use strict;
use warnings;
use base qw'Sophie::Scan::RpmParser';

use File::MMagic;

sub run {
    my ($self, $rpm, $pkgid, $added) = @_;
    my $scan = $self->base;

    if (!$added) { return 1}

    $rpm =~ /src\.rpm$/ and return 1;

    my %filelist;
    foreach ($scan->base->resultset('Files')->search(
            { pkgid => $pkgid, dirname => { LIKE => '/etc/%' }, },
        )->all) {
        $filelist{$_->dirname . $_->basename} = $_;
    }
    keys(%filelist) or return 1; # Nothing to do

    $self->traverse_cpio(
        $rpm,
        sub {
            my ($file) = @_;
            my $fname = $file->name;
            $fname =~ s/^\.\///;
            $fname =~ /^\// or $fname = '/' . $fname;
            $filelist{$fname} or return 1;
            if ($filelist{$fname}->size > 500 * 1024) {
                return 1;
            }

            my $content = $file->get_content;

            my $mm = new File::MMagic;
            $mm->checktype_contents($content) =~ /^application\// and return 1;

            eval {
                $scan->base->storage->txn_do(
                    sub {
                        $scan->base->resultset('BinFiles')->find(
                            {  
                                count => $filelist{$fname}->count,
                                pkgid => $pkgid,
                            }
                        )->update(
                            {
                                contents => $content,
                                has_content => 1,
                            }
                        );

                    }
                );
            };
            return 1;
        }
    );
}

1;
