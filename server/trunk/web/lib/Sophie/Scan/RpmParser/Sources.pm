package Sophie::Scan::RpmParser::Sources;

use strict;
use warnings;
use base qw'Sophie::Scan::RpmParser';

use File::Temp;
use File::Copy;
use Archive::Cpio;
use Encode::Guess;
use Encode;
use File::MMagic;

sub run {
    my ($self, $rpm, $pkgid, $added) = @_;
    my $scan = $self->base;

    if (!$added) { return 1}

    $rpm =~ /\.src\.rpm$/ or return 1;

    my %filelist;
    foreach ($scan->base->resultset('SrcFiles')->search(
        {
            pkgid => $pkgid,
        }
        )->all) {
        $filelist{$_->basename} = $_;
    }

    $self->traverse_cpio(
        $rpm,
        sub {
            my ($file) = @_;
            my $fname = $file->name;
            $fname =~ s/^\.\///;
            if ($filelist{$fname}->size > 2 * 1024 * 1024) {
                return 1;
            }

            my $rawcontent = $file->get_content;

            my $mm = new File::MMagic;
            $mm->checktype_contents($rawcontent) =~ /^application\// and return 1;

            my $content;
            if ($fname =~ /\.spec$/) {
                foreach my $line (split("\n", $rawcontent)) {
                    my $enc = guess_encoding($line, qw/latin1/);
                    if ($enc && ref $enc) {
                        $content .= $enc->decode($line) . "\n";
                    } else {
                        $content .= $line . "\n";
                    }
                }
            } else {
                $content = $rawcontent;
            }
            eval {
                $scan->base->storage->txn_do(
                    sub {
                        $filelist{$fname}->update(
                            {
                                contents => $content,
                                has_content => 1,
                            }
                        );
                    }
                );
            };
            warn $@ if ($@);
            return 1;
        }
    );
}

1;
