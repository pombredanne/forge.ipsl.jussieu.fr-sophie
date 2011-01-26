package Sophie::Scan::RpmParser::Desktopfile;

use strict;
use warnings;
use base qw'Sophie::Scan::RpmParser';

use File::Temp;
use File::Copy;
use Archive::Cpio;
use Config::IniFiles;

sub run {
    my ($self, $rpm, $pkgid, $added) = @_;
    my $scan = $self->base;

    if (!$added) { return 1}

    $rpm =~ /\.src\.rpm$/ and return 1;

    my %filelist;
    foreach ($scan->base->resultset('Files')->search(
        {
            pkgid => $pkgid,
            dirname => { LIKE => '/usr/share/applications/%' },
            basename => { LIKE => '%.desktop' },
        }
        )->all) {
        $filelist{$_->dirname . $_->basename} = $_;
    }

    keys(%filelist) or return 1;

    $self->traverse_cpio(
        $rpm,
        sub {
            my ($file) = @_;
            my $fname = $file->name;
            $fname =~ s/^\.//;
            $fname =~ /^\// or $fname = '/' . $fname;
            $filelist{$fname} or return 1;

            # security
            if ($filelist{$fname}->size > 2 * 1024 * 1024) {
                return 1;
            }

            my $content = $file->get_content;
            my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.cpio' );
            unlink($tmp->filename);
            print $tmp $content;
            seek($tmp, 0, 0);

            my $ini;
            eval { $ini = Config::IniFiles->new(-file => $tmp) };
            $ini or return 1;
            $tmp = undef;

            eval {
                $scan->base->storage->txn_do(
                    sub {
                        $scan->base->resultset('BinFiles')->find(
                            {
                                count => $filelist{$fname}->count,
                                pkgid => $pkgid,
                            }
                        )->update({
                                contents => $content,
                                has_content => 1,
                        });
                        my $dfile = $scan->base->resultset('DesktopFiles')
                            ->find_or_create(
                            {
                                count => $filelist{$fname}->count,
                                pkgid => $pkgid,
                            }
                        );
                        foreach my $param ($ini->Parameters('Desktop Entry')) {
                            my ($key, $locale) = $param =~ /^([^\[]+)(?:\[(.*)\])?$/;
                            my $val =  $ini->val('Desktop Entry', $param, undef);
                            $scan->base->resultset('DesktopEntries')->find_or_create(
                                {
                                    desktop_file => $dfile->desktop_file_pkey,
                                    key => $key,
                                    locale => $locale || '',
                                    value => $val,
                                }
                            );
                        }
                    }
                );
            };
            warn $@ if ($@);
            return 1;
        }
    );
}

1;
